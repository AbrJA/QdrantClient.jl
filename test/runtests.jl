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
        Point(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "a", "n" => 1)),
        Point(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "a", "n" => 2)),
        Point(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0],
                    payload=Dict{String,Any}("group" => "b", "n" => 3)),
    ]
end

# ═══════════════════════════════════════════════════════════════════════════
# Unit Tests
# ═══════════════════════════════════════════════════════════════════════════

@testset "QdrantClient.jl v1.0" begin

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

        @test QueryRequest <: AbstractRequest

        @test Filter <: AbstractCondition
        @test FieldCondition <: AbstractCondition
        @test MatchValue <: AbstractCondition
        @test MatchAny <: AbstractCondition
        @test MatchText <: AbstractCondition
        @test RangeCondition <: AbstractCondition
        @test HasIdCondition <: AbstractCondition
        @test IsEmptyCondition <: AbstractCondition
        @test IsNullCondition <: AbstractCondition

        @test Point <: AbstractQdrantType
        @test NamedVector <: AbstractQdrantType

        # Response types
        @test UpdateResponse <: AbstractResponse
        @test CountResponse <: AbstractResponse
        @test ScoredPoint <: AbstractResponse
        @test Record <: AbstractResponse
        @test ScrollResponse <: AbstractResponse
        @test QueryResponse <: AbstractResponse
        @test GroupResult <: AbstractResponse
        @test GroupsResponse <: AbstractResponse
        @test SnapshotInfo <: AbstractResponse
        @test CollectionDescription <: AbstractResponse
        @test AliasDescription <: AbstractResponse
        @test HealthResponse <: AbstractResponse
        @test FacetHit <: AbstractResponse
        @test FacetResponse <: AbstractResponse
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

        @testset "Point with Int id" begin
            pt = Point(id=1, vector=Float32[1.0, 2.0, 3.0])
            j = JSON.json(pt; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["id"] == 1
            @test parsed["vector"] == [1.0, 2.0, 3.0]
            @test !haskey(parsed, "payload")
        end

        @testset "Point with UUID id" begin
            u = uuid4()
            pt = Point(id=u, vector=Float32[0.1, 0.2],
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

        @testset "QueryRequest using_ → using tag" begin
            qr = QueryRequest(query=Float32[1.0, 0.0], limit=3, using_="image")
            j = JSON.json(qr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["using"] == "image"
            @test !haskey(parsed, "using_")
        end

        @testset "QueryRequest basic" begin
            qr = QueryRequest(query=Float32[1.0, 0.0], limit=5, with_payload=true)
            j = JSON.json(qr; omit_null=true)
            parsed = JSON.parse(j)
            @test parsed["limit"] == 5
            @test parsed["with_payload"] === true
            @test !haskey(parsed, "filter")
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

        cfg = CollectionConfig(
            vectors=VectorParams(size=128, distance=Cosine),
            hnsw_config=HnswConfig(m=32),
        )
        s2 = serialize_body(cfg)
        p2 = JSON.parse(s2)
        @test p2["vectors"]["size"] == 128
        @test p2["hnsw_config"]["m"] == 32
        @test !haskey(p2, "wal_config")

        d = Dict("a" => 1, "b" => nothing, "c" => [], "d" => "content")
        sd = serialize_body(d)
        pd = JSON.parse(sd)
        @test pd["a"] == 1
        @test pd["d"] == "content"
        @test !haskey(pd, "b")
        @test !haskey(pd, "c")
    end

    # ── QdrantConnection ──────────────────────────────────────────────────
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

        c3 = QdrantConnection(host="test.com", port=1234)
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

    # ── Global QdrantConnection ─────────────────────────────────────────
    @testset "Global QdrantConnection" begin
        c1 = QdrantConnection(host="host1")
        set_client!(c1)
        @test get_client().transport.host == "host1"

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
                @test colls isa Vector{CollectionDescription}
                names = [c.name for c in colls]
                @test coll in names

                exists = collection_exists(CONN, coll)
                @test exists === true

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
                @test aliases isa Vector{AliasDescription}
                alias_names = [a.alias_name for a in aliases]
                @test a1 in alias_names

                ca = list_collection_aliases(CONN, coll)
                @test ca isa Vector{AliasDescription}
                @test any(a.alias_name == a1 for a in ca)

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
                @test res isa UpdateResponse
                @test res.status == "completed"

                got = get_points(CONN, coll, [1, 2]; with_vectors=true, with_payload=true)
                @test length(got) == 2
                @test got[1] isa Record
                @test got[1].id == 1
                @test got[1].payload["group"] == "a"
                @test length(got[1].vector) == 4

                single = get_points(CONN, coll, 1; with_payload=true)
                @test length(single) == 1
                @test single[1].id == 1

                rec = get_point(CONN, coll, 1)
                @test rec isa Record
                @test rec.id == 1

                cnt = count_points(CONN, coll; exact=true)
                @test cnt isa CountResponse
                @test cnt.count == 3

                delete_points(CONN, coll, [2]; wait=true)
                cnt2 = count_points(CONN, coll; exact=true)
                @test cnt2.count == 2

                delete_points(CONN, coll, 3; wait=true)
                cnt3 = count_points(CONN, coll; exact=true)
                @test cnt3.count == 1

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
                    Point(id=u1, vector=Float32[1.0, 0.0, 0.0, 0.0],
                                payload=Dict{String,Any}("label" => "first")),
                    Point(id=u2, vector=Float32[0.0, 1.0, 0.0, 0.0],
                                payload=Dict{String,Any}("label" => "second")),
                ]
                res = upsert_points(CONN, coll, pts; wait=true)
                @test res.status == "completed"

                got = get_points(CONN, coll, [u1]; with_payload=true)
                @test length(got) == 1
                @test string(got[1].id) == string(u1)
                @test got[1].payload["label"] == "first"

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
                @test res.status == "completed"

                set_payload(CONN, coll, Dict("solo" => "yes"), 1)

                after = get_points(CONN, coll, [1, 2]; with_payload=true)
                @test after[1].payload["flag"] === true
                @test after[2].payload["flag"] === true
                @test after[1].payload["solo"] == "yes"

                delete_payload(CONN, coll, ["flag"], [2])
                p2 = get_points(CONN, coll, [2]; with_payload=true)
                @test !haskey(p2[1].payload, "flag")

                clear_payload(CONN, coll, [3]; wait=true)
                p3 = get_points(CONN, coll, [3]; with_payload=true)
                @test isempty(p3[1].payload)

                cleanup_collection(CONN, coll)
            end

            # ── Overwrite Payload ───────────────────────────────────────
            @testset "Overwrite Payload" begin
                coll = unique_name("overpay")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                res = overwrite_payload(CONN, coll, Dict("new_field" => "only"), [1])
                @test res isa UpdateResponse
                @test res.status == "completed"

                p = get_points(CONN, coll, [1]; with_payload=true)
                @test p[1].payload["new_field"] == "only"
                @test !haskey(p[1].payload, "group")

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
                @test res.status == "completed"

                pts = get_points(CONN, coll, [1, 2]; with_payload=true)
                @test pts[1].payload["filtered"] === true
                @test pts[2].payload["filtered"] === true

                p3 = get_points(CONN, coll, [3]; with_payload=true)
                @test !haskey(p3[1].payload, "filtered")

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
                @test result isa ScrollResponse
                @test length(result.points) == 3
                @test result.points[1] isa Record

                result2 = scroll_points(CONN, coll; limit=2)
                @test length(result2.points) == 2
                @test result2.next_page_offset !== nothing

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
                @test qr isa QueryResponse
                @test length(qr.points) == 2
                @test qr.points[1] isa ScoredPoint
                @test qr.points[1].id == 1

                qb = query_batch(CONN, coll, [
                    QueryRequest(query=Float32[1, 0, 0, 0], limit=2),
                    QueryRequest(query=Float32[0, 1, 0, 0], limit=1),
                ])
                @test length(qb) == 2
                @test qb[1] isa QueryResponse
                @test length(qb[1].points) == 2
                @test length(qb[2].points) == 1

                cleanup_collection(CONN, coll)
            end

            # ── Query with Filter ───────────────────────────────────────
            @testset "Query with Filter" begin
                coll = unique_name("qfilt")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                create_payload_index(CONN, coll, "group";
                    field_schema="keyword", wait=true)

                f = Filter(must=Any[
                    Dict("key" => "group", "match" => Dict("value" => "a"))
                ])
                qr = query_points(CONN, coll,
                    QueryRequest(query=Float32[1, 0, 0, 0], limit=10,
                        filter=f, with_payload=true))
                @test length(qr.points) == 2
                @test all(p.payload["group"] == "a" for p in qr.points)

                cleanup_collection(CONN, coll)
            end

            # ── Query with SearchParams ─────────────────────────────────
            @testset "Query with SearchParams" begin
                coll = unique_name("qparams")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)

                qr = query_points(CONN, coll,
                    QueryRequest(query=Float32[1, 0, 0, 0], limit=2,
                        params=SearchParams(exact=true)))
                @test length(qr.points) == 2

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
                @test snap isa SnapshotInfo
                @test !isempty(snap.name)

                snaps = list_snapshots(CONN, coll)
                @test snaps isa Vector{SnapshotInfo}
                @test length(snaps) >= 1
                @test snap.name in [s.name for s in snaps]

                @test delete_snapshot(CONN, coll, snap.name) === true

                cleanup_collection(CONN, coll)
            end

            # ── Full Snapshots ──────────────────────────────────────────
            @testset "Full Snapshots" begin
                snap = create_full_snapshot(CONN)
                @test snap isa SnapshotInfo
                @test !isempty(snap.name)

                snaps = list_full_snapshots(CONN)
                @test snaps isa Vector{SnapshotInfo}
                @test length(snaps) >= 1

                @test delete_full_snapshot(CONN, snap.name) === true
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
                @test res isa UpdateResponse
                @test res.status == "completed"

                res2 = create_payload_index(CONN, coll, "n";
                    field_schema="integer", wait=true)
                @test res2.status == "completed"

                res3 = delete_payload_index(CONN, coll, "group"; wait=true)
                @test res3.status == "completed"

                cleanup_collection(CONN, coll)
            end

            # ── Text Index ──────────────────────────────────────────────
            @testset "Text Index" begin
                coll = unique_name("tidx")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

                pts = [
                    Point(id=1, vector=Float32[1, 0, 0, 0],
                        payload=Dict{String,Any}("text" => "hello world")),
                    Point(id=2, vector=Float32[0, 1, 0, 0],
                        payload=Dict{String,Any}("text" => "goodbye world")),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                tip = TextIndexParams(tokenizer="word", lowercase=true)
                res = create_payload_index(CONN, coll, "text";
                    field_schema=tip, wait=true)
                @test res.status == "completed"

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
                    Point(id=1,
                        vector=Dict{String,Vector{Float32}}(
                            "image" => Float32[1, 0, 0, 0],
                            "text" => Float32[0, 1, 0, 0],
                        ),
                        payload=Dict{String,Any}("label" => "first")),
                    Point(id=2,
                        vector=Dict{String,Vector{Float32}}(
                            "image" => Float32[0, 1, 0, 0],
                            "text" => Float32[1, 0, 0, 0],
                        ),
                        payload=Dict{String,Any}("label" => "second")),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                qr = query_points(CONN, coll,
                    QueryRequest(
                        query=Float32[1, 0, 0, 0],
                        using_="image",
                        limit=2, with_payload=true))
                @test length(qr.points) == 2
                @test qr.points[1].id == 1

                qr2 = query_points(CONN, coll,
                    QueryRequest(
                        query=Float32[1, 0, 0, 0],
                        using_="text",
                        limit=2, with_payload=true))
                @test length(qr2.points) == 2
                @test qr2.points[1].id == 2

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
                    Point(id=1, vector=Dict{String,Vector{Float32}}("dense" => Float32[1, 0, 0, 0])),
                    Point(id=2, vector=Dict{String,Vector{Float32}}("dense" => Float32[0, 1, 0, 0])),
                ]
                upsert_points(CONN, coll, pts; wait=true)

                update_vectors(CONN, coll, [
                    Dict("id" => 1, "vector" => Dict("dense" => Float32[0.5, 0.5, 0, 0]))
                ])

                got = get_points(CONN, coll, [1]; with_vectors=true)
                v = got[1].vector["dense"]
                @test v[1] ≈ 0.5 atol=0.01
                @test v[2] ≈ 0.5 atol=0.01

                delete_vectors(CONN, coll, ["dense"], [2]; wait=true)

                cleanup_collection(CONN, coll)
            end

            # ── Service API ─────────────────────────────────────────────
            @testset "Service API" begin
                health = health_check(CONN)
                @test health isa HealthResponse
                @test contains(health.title, "qdrant")
                @test !isempty(health.version)

                ver = get_version(CONN)
                @test ver isa HealthResponse
                @test ver.version == health.version

                telemetry = get_telemetry(CONN)
                @test telemetry isa AbstractDict

                metrics = get_metrics(CONN)
                @test metrics isa String
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
                @test res isa Vector{UpdateResponse}
                @test length(res) >= 1

                cnt = count_points(CONN, coll; exact=true)
                @test cnt.count == 2

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

            # ── Facet ───────────────────────────────────────────────────
            @testset "Facet" begin
                coll = unique_name("facet")
                cleanup_collection(CONN, coll)
                create_collection(CONN, coll,
                    CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
                upsert_points(CONN, coll, fixture_points(); wait=true)
                create_payload_index(CONN, coll, "group";
                    field_schema="keyword", wait=true)

                result = facet(CONN, coll, "group")
                @test result isa FacetResponse
                @test length(result.hits) >= 1
                @test result.hits[1] isa FacetHit

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
            pts = [Point(id=i, vector=Float32.(randn(128)),
                    payload=Dict{String,Any}("idx" => i))
                   for i in 1:n_points]

            t_upsert = @elapsed upsert_points(CONN, coll, pts; wait=true)
            @test t_upsert < 30.0
            @info "Benchmark: upsert $n_points points" time_s=round(t_upsert, digits=3)

            query_vec = Float32.(randn(128))
            t_query = @elapsed for _ in 1:10
                query_points(CONN, coll,
                    QueryRequest(query=query_vec, limit=10))
            end
            @test t_query < 30.0
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

end  # QdrantClient.jl v1.0

# ── gRPC Tests ───────────────────────────────────────────────────────────
include("test_grpc.jl")
