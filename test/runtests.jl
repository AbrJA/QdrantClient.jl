using Test
using UUIDs
using HTTP
using JSON
using QdrantClient

# ── Helpers ──────────────────────────────────────────────────────────────

const CONN = QdrantConnection()
unique_name(prefix="jl") = string(prefix, "_", replace(string(uuid4()), "-" => ""))

function qdrant_available(c::QdrantConnection=CONN)
    try
        health_check(c)
        true
    catch
        false
    end
end

function cleanup_collection(c::QdrantConnection, name)
    try; delete_collection(c, name); catch; end
end

function cleanup_alias(c::QdrantConnection, alias)
    try; delete_alias(c, alias); catch; end
end

function fixture_points()
    [
        PointStruct(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "a", "n" => 1)),
        PointStruct(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "a", "n" => 2)),
        PointStruct(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "b", "n" => 3)),
    ]
end

# ═══════════════════════════════════════════════════════════════════════════
# Unit Tests
# ═══════════════════════════════════════════════════════════════════════════

@testset "QdrantClient.jl v0.3.0" begin

    # ── Type Hierarchy ──────────────────────────────────────────────────
    @testset "Type Hierarchy" begin
        @test VectorParams <: AbstractConfig
        @test SparseVectorParams <: AbstractConfig
        @test CollectionConfig <: AbstractConfig
        @test CollectionUpdate <: AbstractConfig
        @test TextIndexParams <: AbstractConfig
        @test HnswConfig <: AbstractConfig
        @test WalConfig <: AbstractConfig
        @test OptimizersConfig <: AbstractConfig
        @test SearchParams <: AbstractConfig
        @test CollectionParamsDiff <: AbstractConfig
        @test LookupLocation <: AbstractConfig
        @test ScalarQuantization <: AbstractConfig
        @test ProductQuantization <: AbstractConfig
        @test BinaryQuantization <: AbstractConfig

        @test SearchRequest <: AbstractRequest
        @test RecommendRequest <: AbstractRequest
        @test QueryRequest <: AbstractRequest
        @test DiscoverRequest <: AbstractRequest

        @test Filter <: AbstractCondition
        @test FieldCondition <: AbstractCondition
        @test MatchValue <: AbstractCondition
        @test MatchAny <: AbstractCondition
        @test MatchText <: AbstractCondition
        @test RangeCondition <: AbstractCondition
        @test HasIdCondition <: AbstractCondition
        @test IsEmptyCondition <: AbstractCondition
        @test IsNullCondition <: AbstractCondition

        @test PointStruct <: AbstractQdrantType
        @test NamedVector <: AbstractQdrantType
    end

    # ── Distance Enum ───────────────────────────────────────────────────
    @testset "Distance Enum" begin
        @test Cosine isa Distance
        @test Euclid isa Distance
        @test Dot isa Distance
        @test Manhattan isa Distance
        @test string(Dot) == "Dot"
        @test string(Cosine) == "Cosine"
        @test string(Euclid) == "Euclid"
        @test string(Manhattan) == "Manhattan"
    end

    # ── PointId Type ────────────────────────────────────────────────────
    @testset "PointId Type" begin
        @test 42 isa PointId
        @test uuid4() isa PointId
        @test !(1.5 isa PointId)
        @test !("string" isa PointId)
    end

    # ── StructUtils Serialization ───────────────────────────────────────
    @testset "StructUtils Serialization" begin
        @testset "VectorParams" begin
            vp = VectorParams(size=4, distance=Dot)
            j = JSON.json(vp; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["size"] == 4
            @test parsed["distance"] == "Dot"
            @test !haskey(parsed, "hnsw_config")
            @test !haskey(parsed, "on_disk")
        end

        @testset "VectorParams with HnswConfig" begin
            vp = VectorParams(size=4, distance=Euclid,
                hnsw_config=HnswConfig(m=32, ef_construct=200))
            j = JSON.json(vp; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["hnsw_config"]["m"] == 32
            @test parsed["hnsw_config"]["ef_construct"] == 200
            @test !haskey(parsed["hnsw_config"], "on_disk")
        end

        @testset "CollectionConfig" begin
            cfg = CollectionConfig(vectors=VectorParams(size=128, distance=Cosine))
            j = JSON.json(cfg; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["vectors"]["size"] == 128
            @test parsed["vectors"]["distance"] == "Cosine"
        end

        @testset "CollectionConfig with typed sub-configs" begin
            cfg = CollectionConfig(
                vectors=VectorParams(size=4, distance=Dot),
                hnsw_config=HnswConfig(m=16),
                optimizers_config=OptimizersConfig(indexing_threshold=10000),
            )
            j = JSON.json(cfg; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["hnsw_config"]["m"] == 16
            @test parsed["optimizers_config"]["indexing_threshold"] == 10000
        end

        @testset "PointStruct with Int id" begin
            pt = PointStruct(id=1, vector=Float32[1.0, 2.0, 3.0])
            j = JSON.json(pt; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["id"] == 1
            @test parsed["vector"] == [1.0, 2.0, 3.0]
            @test !haskey(parsed, "payload")
        end

        @testset "PointStruct with UUID id" begin
            u = uuid4()
            pt = PointStruct(id=u, vector=Float32[0.1, 0.2],
                             payload=Dict{String,Any}("color" => "red"))
            j = JSON.json(pt; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["id"] == string(u)
            @test parsed["payload"]["color"] == "red"
        end

        @testset "NamedVector" begin
            nv = NamedVector(name="image", vector=Float32[1.0, 0.0, 0.0, 0.0])
            j = JSON.json(nv; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["name"] == "image"
            @test length(parsed["vector"]) == 4
        end

        @testset "SearchRequest" begin
            sr = SearchRequest(vector=Float32[1.0, 0.0], limit=5, with_payload=true)
            j = JSON.json(sr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["limit"] == 5
            @test parsed["with_payload"] === true
            @test !haskey(parsed, "filter")
            @test !haskey(parsed, "params")
        end

        @testset "SearchRequest with SearchParams" begin
            sr = SearchRequest(vector=Float32[1.0], limit=5,
                params=SearchParams(exact=true, hnsw_ef=128))
            j = JSON.json(sr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["params"]["exact"] === true
            @test parsed["params"]["hnsw_ef"] == 128
        end

        @testset "RecommendRequest using_ → using tag" begin
            rr = RecommendRequest(positive=Any[1, 2], limit=5, using_="dense")
            j = JSON.json(rr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["using"] == "dense"
            @test !haskey(parsed, "using_")
        end

        @testset "QueryRequest using_ → using tag" begin
            qr = QueryRequest(query=Float32[1.0, 0.0], limit=3, using_="image")
            j = JSON.json(qr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["using"] == "image"
            @test !haskey(parsed, "using_")
        end

        @testset "DiscoverRequest using_ → using tag" begin
            dr = DiscoverRequest(target=Float32[1.0, 0.0], limit=3, using_="image")
            j = JSON.json(dr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["using"] == "image"
            @test !haskey(parsed, "using_")
        end

        @testset "Filter" begin
            f = Filter(must=Any[Dict("key" => "color", "match" => Dict("value" => "red"))])
            j = JSON.json(f; omit_null=true, omit_empty=true)
            parsed = JSON.parse(j)
            @test length(parsed["must"]) == 1
            @test !haskey(parsed, "should")
        end

        @testset "TextIndexParams" begin
            tip = TextIndexParams(tokenizer="word", lowercase=true)
            j = JSON.json(tip; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["type"] == "text"
            @test parsed["tokenizer"] == "word"
            @test parsed["lowercase"] === true
        end

        @testset "SearchParams" begin
            sp = SearchParams(hnsw_ef=128, exact=false)
            j = JSON.json(sp; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["hnsw_ef"] == 128
            @test parsed["exact"] === false
            @test !haskey(parsed, "quantization")
        end

        @testset "OptimizersConfig" begin
            oc = OptimizersConfig(indexing_threshold=10000, flush_interval_sec=5)
            j = JSON.json(oc; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["indexing_threshold"] == 10000
            @test parsed["flush_interval_sec"] == 5
            @test !haskey(parsed, "deleted_threshold")
        end

        @testset "LookupLocation" begin
            ll = LookupLocation(collection="other", vector="dense")
            j = JSON.json(ll; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["collection"] == "other"
            @test parsed["vector"] == "dense"
        end

        @testset "CollectionUpdate with typed configs" begin
            cu = CollectionUpdate(
                optimizers_config=OptimizersConfig(indexing_threshold=10000),
                params=CollectionParamsDiff(replication_factor=2),
            )
            j = JSON.json(cu; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["optimizers_config"]["indexing_threshold"] == 10000
            @test parsed["params"]["replication_factor"] == 2
        end

        @testset "ScalarQuantization" begin
            sq = ScalarQuantization(scalar=ScalarQuantizationConfig(quantile=0.99))
            j = JSON.json(sq; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["scalar"]["type"] == "int8"
            @test parsed["scalar"]["quantile"] == 0.99
        end
    end

    # ── serialize_body ──────────────────────────────────────────────────
    @testset "serialize_body" begin
        vp = VectorParams(size=4, distance=Dot)
        s = serialize_body(vp)
        @test s isa String
        parsed = JSON.parse(s)
        @test parsed["size"] == 4
        @test parsed["distance"] == "Dot"
        @test !haskey(parsed, "hnsw_config")

        # Test with nested struct
        cfg = CollectionConfig(
            vectors=VectorParams(size=128, distance=Cosine),
            hnsw_config=HnswConfig(m=32),
        )
        s2 = serialize_body(cfg)
        p2 = JSON.parse(s2)
        @test p2["vectors"]["size"] == 128
        @test p2["hnsw_config"]["m"] == 32
        @test !haskey(p2, "wal_config")

        # Test Dict serialization
        d = Dict("a" => 1, "b" => nothing, "c" => [], "d" => "content")
        sd = serialize_body(d)
        pd = JSON.parse(sd)
        @test pd["a"] == 1
        @test pd["d"] == "content"
        @test !haskey(pd, "b")
        @test !haskey(pd, "c")
    end

    # ── QdrantConnection / Client ───────────────────────────────────────
    @testset "QdrantConnection" begin
        c = QdrantConnection()
        @test c.transport isa HTTPTransport
        @test c.transport.host == "localhost"
        @test c.transport.port == 6333
        @test c.transport.api_key === nothing
        @test c.transport.tls === false

        c2 = QdrantConnection(host="example.com", port=8080, api_key="secret", tls=true)
        @test c2.transport.host == "example.com"
        @test c2.transport.port == 8080
        @test c2.transport.api_key == "secret"
        @test c2.transport.tls === true

        # Client alias
        c3 = Client(host="test.com", port=1234)
        @test c3 isa QdrantConnection
        @test c3.transport.host == "test.com"
    end

    # ── Transport ───────────────────────────────────────────────────────
    @testset "Transport" begin
        t = HTTPTransport(host="myhost", port=9999, tls=true, api_key="abc")
        @test QdrantClient.base_url(t) == "https://myhost:9999"

        t2 = HTTPTransport(host="local", port=6333)
        @test QdrantClient.base_url(t2) == "http://local:6333"

        @test QdrantClient.transport_url(t2, "/collections") == "http://local:6333/collections"
        @test QdrantClient.transport_url(t2, "collections") == "http://local:6333/collections"
    end

    # ── Headers ─────────────────────────────────────────────────────────
    @testset "Headers" begin
        t_with_key = HTTPTransport(api_key="secret")
        headers = QdrantClient.transport_headers(t_with_key)
        hd = Dict(headers)
        @test hd["Content-Type"] == "application/json"
        @test hd["api-key"] == "secret"
        @test startswith(hd["User-Agent"], "QdrantClient.jl/")

        t_no_key = HTTPTransport()
        headers2 = QdrantClient.transport_headers(t_no_key)
        hd2 = Dict(headers2)
        @test !haskey(hd2, "api-key")
    end

    # ── Global Client ───────────────────────────────────────────────────
    @testset "Global Client" begin
        c1 = QdrantConnection(host="host1")
        set_client!(c1)
        @test get_client().transport.host == "host1"

        # Restore default
        set_client!(QdrantConnection())
        @test get_client().transport.host == "localhost"
    end

    # ── Error Type ──────────────────────────────────────────────────────
    @testset "QdrantError" begin
        err = QdrantError(404, "Not found")
        @test err.status == 404
        @test err.message == "Not found"
        @test err.detail === nothing

        err2 = QdrantError(500, "Internal", Dict("info" => "details"))
        @test err2.detail["info"] == "details"

        buf = IOBuffer()
        showerror(buf, err)
        s = String(take!(buf))
        @test contains(s, "404")
        @test contains(s, "Not found")
    end

    # ── parse_response ──────────────────────────────────────────────────
    @testset "parse_response" begin
        empty_resp = HTTP.Response(200, []; body=UInt8[])
        @test QdrantClient.parse_response(empty_resp) === nothing

        wrapped = HTTP.Response(200, [];
            body=Vector{UInt8}(JSON.json(Dict(
                "status" => "ok", "time" => 0.01,
                "result" => Dict("count" => 7)
            )))
        )
        r = QdrantClient.parse_response(wrapped)
        @test r["count"] == 7

        raw = HTTP.Response(200, [];
            body=Vector{UInt8}(JSON.json(Dict("key" => "val")))
        )
        r2 = QdrantClient.parse_response(raw)
        @test r2["key"] == "val"
    end

    # ═══════════════════════════════════════════════════════════════════
    # Integration Tests (require Qdrant on localhost:6333)
    # ═══════════════════════════════════════════════════════════════════

    @testset "Integration" begin
        if !qdrant_available()
            @warn "Qdrant not available on localhost:6333 — skipping integration tests"
            @test_skip "Qdrant not available"
        else
            # ── Collection Lifecycle ────────────────────────────────────
            @testset "Collection Lifecycle" begin
                coll = unique_name("coll")
                cleanup_collection(CONN, coll)

                result = create_collection(CONN, coll, CollectionConfig(
                    vectors=VectorParams(size=4, distance=Dot)
                ))
                @test result === true

                colls = list_collections(CONN)
                if colls isa AbstractDict && haskey(colls, "collections")
                    names = [c["name"] for c in colls["collections"]]
                    @test coll in names
                end

                exists = collection_exists(CONN, coll)
                @test exists isa AbstractDict
                @test exists["exists"] === true

                info = get_collection(CONN, coll)
                @test info["status"] == "green"
                @test info["config"]["params"]["vectors"]["size"] == 4

                @test delete_collection(CONN, coll) === true
            end

            # ── Collection create with kwargs ───────────────────────────
            @testset "Collection create kwargs" begin
                coll = unique_name("ckw")
                cleanup_collection(CONN, coll)

                create_collection(CONN, coll;
                    vectors=VectorParams(size=4, distance=Cosine))
                info = get_collection(CONN, coll)
                @test info["config"]["params"]["vectors"]["distance"] == "Cosine"

                cleanup_collection(CONN, coll)
            end

            # ── Collection with typed configs ───────────────────────────
            @testset "Collection with typed configs" begin
                coll = unique_name("cfg")
                cleanup_collection(CONN, coll)

                create_collection(CONN, coll, CollectionConfig(
                    vectors=VectorParams(size=4, distance=Dot),
                    hnsw_config=HnswConfig(m=32, ef_construct=200),
                    optimizers_config=OptimizersConfig(indexing_threshold=10000),
                ))
                info = get_collection(CONN, coll)
                @test info["config"]["hnsw_config"]["m"] == 32
                @test info["config"]["optimizer_config"]["indexing_threshold"] == 10000

                cleanup_collection(CONN, coll)
            end

            # ── Aliases ─────────────────────────────────────────────────
            @testset "Aliases" begin
                coll = unique_name("alias")
                a1 = coll * "_a1"
                a2 = coll * "_a2"
                cleanup_alias(CONN, a1); cleanup_alias(CONN, a2)
                cleanup_collection(CONN, coll)

                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                @test create_alias(CONN, a1, coll) === true

                aliases = list_aliases(CONN)
                if aliases isa AbstractDict && haskey(aliases, "aliases")
                    alias_names = [a["alias_name"] for a in aliases["aliases"]]
                    @test a1 in alias_names
                end

                ca = list_collection_aliases(CONN, coll)
                if ca isa AbstractDict && haskey(ca, "aliases")
                    @test any(a["alias_name"] == a1 for a in ca["aliases"])
                end

                @test rename_alias(CONN, a1, a2) === true
                @test delete_alias(CONN, a2) === true

                cleanup_collection(CONN, coll)
            end

            # ── Points CRUD ─────────────────────────────────────────────
            @testset "Points CRUD" begin
                coll = unique_name("pts")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                pts = fixture_points()

                res = upsert_points(CONN, coll, pts; wait=true)
                @test res["status"] == "completed"

                got = get_points(CONN, coll, [1, 2]; with_vectors=true, with_payload=true)
                @test length(got) == 2
                @test got[1]["id"] == 1
                @test got[1]["payload"]["group"] == "a"
                @test length(got[1]["vector"]) == 4

                single = get_points(CONN, coll, 1; with_payload=true)
                @test length(single) == 1
                @test single[1]["id"] == 1

                cnt = count_points(CONN, coll; exact=true)
                @test cnt["count"] == 3

                delete_points(CONN, coll, [2]; wait=true)
                cnt2 = count_points(CONN, coll; exact=true)
                @test cnt2["count"] == 2

                delete_points(CONN, coll, 3; wait=true)
                cnt3 = count_points(CONN, coll; exact=true)
                @test cnt3["count"] == 1

                cleanup_collection(CONN, coll)
            end

            # ── Points with UUID IDs ────────────────────────────────────
            @testset "Points UUID IDs" begin
                coll = unique_name("uuid")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                u1 = uuid4()
                u2 = uuid4()
                pts = [
                    PointStruct(id=u1, vector=Float32[1.0, 0.0, 0.0, 0.0],
                                payload=Dict{String,Any}("label" => "first")),
                    PointStruct(id=u2, vector=Float32[0.0, 1.0, 0.0, 0.0],
                                payload=Dict{String,Any}("label" => "second")),
                ]
                res = upsert_points(CONN, coll, pts; wait=true)
                @test res["status"] == "completed"

                got = get_points(CONN, coll, [u1]; with_payload=true)
                @test length(got) == 1
                @test got[1]["id"] == string(u1)
                @test got[1]["payload"]["label"] == "first"

                cleanup_collection(CONN, coll)
            end

            # ── Payload Operations ──────────────────────────────────────
            @testset "Payload Operations" begin
                coll = unique_name("payload")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                res = set_payload(CONN, coll, Dict("flag" => true), [1, 2])
                @test res["status"] == "completed"

                set_payload(CONN, coll, Dict("solo" => "yes"), 1)

                after = get_points(CONN, coll, [1, 2]; with_payload=true)
                @test after[1]["payload"]["flag"] === true
                @test after[2]["payload"]["flag"] === true
                @test after[1]["payload"]["solo"] == "yes"

                delete_payload(CONN, coll, ["flag"], [2])
                p2 = get_points(CONN, coll, [2]; with_payload=true)
                @test !haskey(p2[1]["payload"], "flag")

                clear_payload(CONN, coll, [3]; wait=true)
                p3 = get_points(CONN, coll, [3]; with_payload=true)
                @test isempty(p3[1]["payload"])

                cleanup_collection(CONN, coll)
            end

            # ── Filter-based Payload Operations ─────────────────────────
            @testset "Filter-based Payload" begin
                coll = unique_name("fpay")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                f = Filter(must=Any[Dict("key" => "group", "match" => Dict("value" => "a"))])
                res = set_payload(CONN, coll, Dict("filtered" => true), f)
                @test res["status"] == "completed"

                pts = get_points(CONN, coll, [1, 2]; with_payload=true)
                @test pts[1]["payload"]["filtered"] === true
                @test pts[2]["payload"]["filtered"] === true

                p3 = get_points(CONN, coll, [3]; with_payload=true)
                @test !haskey(p3[1]["payload"], "filtered")

                cleanup_collection(CONN, coll)
            end

            # ── Scroll ──────────────────────────────────────────────────
            @testset "Scroll" begin
                coll = unique_name("scroll")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                result = scroll_points(CONN, coll; limit=10, with_payload=true)
                @test length(result["points"]) == 3

                result2 = scroll_points(CONN, coll; limit=2)
                @test length(result2["points"]) == 2

                cleanup_collection(CONN, coll)
            end

            # ── Search ──────────────────────────────────────────────────
            @testset "Search" begin
                coll = unique_name("search")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                hits = search_points(CONN, coll,
                    SearchRequest(vector=Float32[1, 0, 0, 0], limit=2, with_payload=true))
                @test length(hits) == 2
                @test hits[1]["id"] == 1

                hits2 = search_points(CONN, coll;
                    vector=Float32[0, 1, 0, 0], limit=1, with_payload=true)
                @test length(hits2) == 1
                @test hits2[1]["id"] == 3

                batch = search_batch(CONN, coll, [
                    SearchRequest(vector=Float32[1, 0, 0, 0], limit=2),
                    SearchRequest(vector=Float32[0, 1, 0, 0], limit=1),
                ])
                @test length(batch) == 2
                @test length(batch[1]) == 2
                @test length(batch[2]) == 1

                cleanup_collection(CONN, coll)
            end

            # ── Search with SearchParams ────────────────────────────────
            @testset "Search with SearchParams" begin
                coll = unique_name("sparams")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                hits = search_points(CONN, coll,
                    SearchRequest(vector=Float32[1, 0, 0, 0], limit=2,
                        params=SearchParams(exact=true)))
                @test length(hits) == 2

                cleanup_collection(CONN, coll)
            end

            # ── Recommend ───────────────────────────────────────────────
            @testset "Recommend" begin
                coll = unique_name("rec")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                recs = recommend_points(CONN, coll,
                    RecommendRequest(positive=Any[1], limit=2, with_payload=true))
                @test length(recs) == 2
                @test all(r["id"] != 1 for r in recs)

                cleanup_collection(CONN, coll)
            end

            # ── Query Points ────────────────────────────────────────────
            @testset "Query Points" begin
                coll = unique_name("query")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                qr = query_points(CONN, coll,
                    QueryRequest(query=Float32[1, 0, 0, 0], limit=2, with_payload=true))
                @test haskey(qr, "points")
                @test length(qr["points"]) == 2
                @test qr["points"][1]["id"] == 1

                qb = query_batch(CONN, coll, [
                    QueryRequest(query=Float32[1, 0, 0, 0], limit=2),
                    QueryRequest(query=Float32[0, 1, 0, 0], limit=1),
                ])
                @test length(qb) == 2

                cleanup_collection(CONN, coll)
            end

            # ── Discovery ───────────────────────────────────────────────
            @testset "Discovery" begin
                coll = unique_name("disc")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                disc = discover_points(CONN, coll,
                    DiscoverRequest(target=Float32[1, 0, 0, 0], limit=2,
                        context=Any[
                            Dict("positive" => 1, "negative" => 3)
                        ],
                        with_payload=true))
                @test length(disc) >= 1

                cleanup_collection(CONN, coll)
            end

            # ── Snapshots ───────────────────────────────────────────────
            @testset "Snapshots" begin
                coll = unique_name("snap")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                snap = create_snapshot(CONN, coll)
                @test haskey(snap, "name")

                snaps = list_snapshots(CONN, coll)
                @test length(snaps) >= 1
                snap_names = [s isa AbstractDict ? s["name"] : "" for s in snaps]
                @test snap["name"] in snap_names

                @test delete_snapshot(CONN, coll, snap["name"]) === true

                cleanup_collection(CONN, coll)
            end

            # ── Payload Index ───────────────────────────────────────────
            @testset "Payload Index" begin
                coll = unique_name("pidx")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                res = create_payload_index(CONN, coll, "group";
                    field_schema="keyword", wait=true)
                @test res["status"] == "completed"

                res2 = create_payload_index(CONN, coll, "n";
                    field_schema="integer", wait=true)
                @test res2["status"] == "completed"

                res3 = delete_payload_index(CONN, coll, "group"; wait=true)
                @test res3["status"] == "completed"

                cleanup_collection(CONN, coll)
            end

            # ── Text Index ──────────────────────────────────────────────
            @testset "Text Index" begin
                coll = unique_name("tidx")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                pts = [
                    PointStruct(id=1, vector=Float32[1, 0, 0, 0],
                        payload=Dict{String,Any}("text" => "hello world")),
                    PointStruct(id=2, vector=Float32[0, 1, 0, 0],
                        payload=Dict{String,Any}("text" => "goodbye world")),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                tip = TextIndexParams(tokenizer="word", lowercase=true)
                res = create_payload_index(CONN, coll, "text";
                    field_schema=tip, wait=true)
                @test res["status"] == "completed"

                cleanup_collection(CONN, coll)
            end

            # ── Multiple / Named Vectors ────────────────────────────────
            @testset "Named Vectors" begin
                coll = unique_name("named")
                cleanup_collection(CONN, coll)

                cfg = CollectionConfig(
                    vectors=Dict{String,VectorParams}(
                        "image" => VectorParams(size=4, distance=Cosine),
                        "text" => VectorParams(size=4, distance=Dot),
                    )
                )
                create_collection(CONN, coll, cfg)

                pts = [
                    PointStruct(id=1,
                        vector=Dict{String,Vector{Float32}}(
                            "image" => Float32[1, 0, 0, 0],
                            "text" => Float32[0, 1, 0, 0],
                        ),
                        payload=Dict{String,Any}("label" => "first")),
                    PointStruct(id=2,
                        vector=Dict{String,Vector{Float32}}(
                            "image" => Float32[0, 1, 0, 0],
                            "text" => Float32[1, 0, 0, 0],
                        ),
                        payload=Dict{String,Any}("label" => "second")),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                # Search with NamedVector struct
                hits = search_points(CONN, coll,
                    SearchRequest(
                        vector=NamedVector(name="image", vector=Float32[1, 0, 0, 0]),
                        limit=2, with_payload=true))
                @test length(hits) == 2
                @test hits[1]["id"] == 1

                hits2 = search_points(CONN, coll,
                    SearchRequest(
                        vector=NamedVector(name="text", vector=Float32[1, 0, 0, 0]),
                        limit=2, with_payload=true))
                @test length(hits2) == 2
                @test hits2[1]["id"] == 2

                cleanup_collection(CONN, coll)
            end

            # ── Vector Operations (update/delete) ───────────────────────
            @testset "Vector Operations" begin
                coll = unique_name("vecops")
                cleanup_collection(CONN, coll)

                cfg = CollectionConfig(
                    vectors=Dict{String,VectorParams}(
                        "dense" => VectorParams(size=4, distance=Dot),
                    )
                )
                create_collection(CONN, coll, cfg)

                pts = [
                    PointStruct(id=1, vector=Dict{String,Vector{Float32}}("dense" => Float32[1, 0, 0, 0])),
                    PointStruct(id=2, vector=Dict{String,Vector{Float32}}("dense" => Float32[0, 1, 0, 0])),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                update_vectors(CONN, coll, [
                    Dict("id" => 1, "vector" => Dict("dense" => Float32[0.5, 0.5, 0, 0]))
                ])

                got = get_points(CONN, coll, [1]; with_vectors=true)
                v = got[1]["vector"]["dense"]
                @test v[1] ≈ 0.5 atol=0.01
                @test v[2] ≈ 0.5 atol=0.01

                delete_vectors(CONN, coll, ["dense"], [2]; wait=true)

                cleanup_collection(CONN, coll)
            end

            # ── Service API ─────────────────────────────────────────────
            @testset "Service API" begin
                health = health_check(CONN)
                @test health["status"] == "healthy"

                telemetry = get_telemetry(CONN)
                @test telemetry isa AbstractDict
            end

            # ── Cluster / Distributed ───────────────────────────────────
            @testset "Cluster Status" begin
                cs = cluster_status(CONN)
                @test cs isa AbstractDict
            end

            # ── Batch Operations ────────────────────────────────────────
            @testset "Batch Points" begin
                coll = unique_name("batch")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                ops = [
                    Dict("upsert" => Dict(
                        "points" => [
                            Dict("id" => 1, "vector" => Float32[1, 0, 0, 0],
                                 "payload" => Dict("k" => "v")),
                            Dict("id" => 2, "vector" => Float32[0, 1, 0, 0]),
                        ]
                    )),
                ]
                res = batch_points(CONN, coll, ops; wait=true)
                @test res isa AbstractVector

                cnt = count_points(CONN, coll; exact=true)
                @test cnt["count"] == 2

                cleanup_collection(CONN, coll)
            end

            # ── Search with Filter ──────────────────────────────────────
            @testset "Search with Filter" begin
                coll = unique_name("sfilt")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                create_payload_index(CONN, coll, "group";
                    field_schema="keyword", wait=true)

                f = Filter(must=Any[
                    Dict("key" => "group", "match" => Dict("value" => "a"))
                ])
                hits = search_points(CONN, coll,
                    SearchRequest(vector=Float32[1, 0, 0, 0], limit=10,
                        filter=f, with_payload=true))
                @test length(hits) == 2
                @test all(h["payload"]["group"] == "a" for h in hits)

                cleanup_collection(CONN, coll)
            end

            # ── Update Collection ───────────────────────────────────────
            @testset "Update Collection" begin
                coll = unique_name("upd")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                result = update_collection(CONN, coll,
                    CollectionUpdate(optimizers_config=OptimizersConfig(
                        indexing_threshold=10000
                    )))
                @test result === true

                cleanup_collection(CONN, coll)
            end

        end  # qdrant_available
    end  # Integration

    # ═══════════════════════════════════════════════════════════════════
    # Benchmarks (lightweight timing)
    # ═══════════════════════════════════════════════════════════════════

    @testset "Benchmarks" begin
        if qdrant_available()
            coll = unique_name("bench")
            cleanup_collection(CONN, coll)
            create_collection(CONN, coll,
                CollectionConfig(vectors=VectorParams(size=128, distance=Dot)))

            n_points = 100
            pts = [PointStruct(id=i, vector=Float32.(randn(128)),
                    payload=Dict{String,Any}("idx" => i))
                   for i in 1:n_points]

            t_upsert = @elapsed upsert_points(CONN, coll, pts; wait=true)
            @test t_upsert < 30.0
            @info "Benchmark: upsert $n_points points" time_s=round(t_upsert, digits=3)

            query_vec = Float32.(randn(128))
            t_search = @elapsed for _ in 1:10
                search_points(CONN, coll,
                    SearchRequest(vector=query_vec, limit=10))
            end
            @test t_search < 30.0
            @info "Benchmark: 10 searches" time_s=round(t_search, digits=3) per_search=round(t_search/10, digits=4)

            t_query = @elapsed for _ in 1:10
                query_points(CONN, coll,
                    QueryRequest(query=query_vec, limit=10))
            end
            @info "Benchmark: 10 queries" time_s=round(t_query, digits=3) per_query=round(t_query/10, digits=4)

            t_scroll = @elapsed scroll_points(CONN, coll; limit=100, with_payload=true)
            @info "Benchmark: scroll 100 points" time_s=round(t_scroll, digits=3)

            t_count = @elapsed for _ in 1:10
                count_points(CONN, coll; exact=true)
            end
            @info "Benchmark: 10 counts" time_s=round(t_count, digits=3)

            t_ser = @elapsed for _ in 1:1000
                serialize_body(VectorParams(size=128, distance=Dot))
            end
            @info "Benchmark: 1000 serialize_body calls" time_s=round(t_ser, digits=4)

            cleanup_collection(CONN, coll)
        else
            @test_skip "Benchmarks need Qdrant"
        end
    end

end  # QdrantClient.jl v0.3.0
