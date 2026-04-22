# ============================================================================
# gRPC Tests for QdrantClient.jl v1.0
# ============================================================================

using Test
using UUIDs
using QdrantClient
using QdrantClient: qdrant, to_proto_point_id, from_proto_point_id,
    to_proto_distance, from_proto_distance,
    julia_value_to_proto, proto_value_to_julia,
    to_proto_payload, from_proto_payload,
    to_proto_vectors, from_proto_vectors,
    to_proto_point, from_proto_scored_point, from_proto_retrieved_point,
    to_proto_filter, to_proto_condition, to_proto_match,
    to_proto_with_payload, to_proto_with_vectors,
    to_proto_search_params, to_proto_points_selector,
    to_proto_vector_params, to_proto_vectors_config,
    to_proto_hnsw_config, to_proto_wal_config, to_proto_optimizers_config,
    to_proto_ordering
using ProtoBuf: OneOf

# ── Helpers ──────────────────────────────────────────────────────────────

const GRPC_CONN = QdrantConnection(GRPCTransport())
const HTTP_CONN = QdrantConnection()
if !@isdefined(unique_name)
    unique_name(prefix="grpc") = string(prefix, "_", replace(string(uuid4()), "-" => ""))
end

function grpc_available(c::QdrantConnection=GRPC_CONN)
    try
        health_check(c)
        true
    catch
        false
    end
end

if !@isdefined(cleanup_collection)
    cleanup_collection(c::QdrantConnection, name) = (try; delete_collection(c, name); catch; end)
end

if !@isdefined(fixture_points)
    fixture_points() = [
        Point(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 1)),
        Point(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 2)),
        Point(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "b", "n" => 3)),
    ]
end

# ═══════════════════════════════════════════════════════════════════════════
# Unit Tests — Type Conversions (no server required)
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Unit Tests" begin

    # ── Transport Construction ──────────────────────────────────────────
    @testset "GRPCTransport construction" begin
        t = GRPCTransport()
        @test t.host == "localhost"
        @test t.port == 6334
        @test t.api_key === nothing
        @test t.timeout == 30
        @test t.tls == false
        @test t.max_message_size == 64 * 1024 * 1024

        t2 = GRPCTransport(host="qdrant.example.com", port=6335, tls=true, api_key="secret")
        @test t2.host == "qdrant.example.com"
        @test t2.port == 6335
        @test t2.tls == true
        @test t2.api_key == "secret"
    end

    @testset "is_grpc dispatch" begin
        grpc = QdrantConnection(GRPCTransport())
        http = QdrantConnection()
        @test is_grpc(grpc) == true
        @test is_grpc(http) == false
    end

    # ── PointId Conversion ──────────────────────────────────────────────
    @testset "PointId conversion" begin
        pid_int = to_proto_point_id(42)
        @test pid_int isa qdrant.PointId
        @test from_proto_point_id(pid_int) == 42

        pid_large = to_proto_point_id(typemax(Int64))
        @test from_proto_point_id(pid_large) == typemax(Int64)

        u = uuid4()
        pid_uuid = to_proto_point_id(u)
        @test pid_uuid isa qdrant.PointId
        @test from_proto_point_id(pid_uuid) == u

        pid_zero = to_proto_point_id(0)
        @test from_proto_point_id(pid_zero) == 0
    end

    # ── Distance Conversion ─────────────────────────────────────────────
    @testset "Distance conversion" begin
        for d in (Cosine, Euclid, Dot, Manhattan)
            proto_d = to_proto_distance(d)
            @test from_proto_distance(proto_d) === d
        end
    end

    # ── Value Conversion ────────────────────────────────────────────────
    @testset "Value conversion roundtrips" begin
        @test proto_value_to_julia(julia_value_to_proto(nothing)) === nothing
        @test proto_value_to_julia(julia_value_to_proto(true)) === true
        @test proto_value_to_julia(julia_value_to_proto(false)) === false
        @test proto_value_to_julia(julia_value_to_proto(42)) == 42
        @test proto_value_to_julia(julia_value_to_proto(0)) == 0
        @test proto_value_to_julia(julia_value_to_proto(-100)) == -100

        v = proto_value_to_julia(julia_value_to_proto(3.14))
        @test v ≈ 3.14

        @test proto_value_to_julia(julia_value_to_proto("hello")) == "hello"
        @test proto_value_to_julia(julia_value_to_proto("")) == ""
        @test proto_value_to_julia(julia_value_to_proto([1, 2, 3])) == [1, 2, 3]
        @test proto_value_to_julia(julia_value_to_proto(["a", "b"])) == ["a", "b"]

        nested = [[1, 2], [3, 4]]
        @test proto_value_to_julia(julia_value_to_proto(nested)) == nested

        d = Dict("a" => 1, "b" => "two")
        result = proto_value_to_julia(julia_value_to_proto(d))
        @test result["a"] == 1
        @test result["b"] == "two"

        nd = Dict("outer" => Dict("inner" => 42))
        result = proto_value_to_julia(julia_value_to_proto(nd))
        @test result["outer"]["inner"] == 42
    end

    # ── Payload Conversion ──────────────────────────────────────────────
    @testset "Payload conversion" begin
        payload = Dict{String,Any}("name" => "test", "count" => 5, "tags" => ["a", "b"])
        proto_p = to_proto_payload(payload)
        @test proto_p isa Dict{String,qdrant.Value}
        result = from_proto_payload(proto_p)
        @test result["name"] == "test"
        @test result["count"] == 5
        @test result["tags"] == ["a", "b"]

        @test to_proto_payload(nothing) == Dict{String,qdrant.Value}()
    end

    # ── Vector Conversion ───────────────────────────────────────────────
    @testset "Vector conversion" begin
        v = Float32[1.0, 2.0, 3.0, 4.0]
        proto_v = to_proto_vectors(v)
        @test proto_v isa qdrant.Vectors
        @test proto_v.vectors_options.name === :vector

        nv = NamedVector(name="image", vector=Float32[1.0, 0.0])
        proto_nv = to_proto_vectors(nv)
        @test proto_nv.vectors_options.name === :vectors

        dv = Dict("text" => Float32[1.0, 0.0], "image" => Float32[0.0, 1.0])
        proto_dv = to_proto_vectors(dv)
        @test proto_dv.vectors_options.name === :vectors
    end

    # ── Point Conversion ────────────────────────────────────────────────
    @testset "Point conversion" begin
        p = Point(id=42, vector=Float32[1.0, 0.0, 0.0, 0.0],
                  payload=Dict{String,Any}("key" => "val"))
        proto_p = to_proto_point(p)
        @test proto_p isa qdrant.PointStruct
        @test from_proto_point_id(proto_p.id) == 42

        u = uuid4()
        p2 = Point(id=u, vector=Float32[1.0, 0.0, 0.0, 0.0])
        proto_p2 = to_proto_point(p2)
        @test from_proto_point_id(proto_p2.id) == u
    end

    # ── Filter Conversion ───────────────────────────────────────────────
    @testset "Filter conversion" begin
        @test to_proto_filter(nothing) === nothing

        f = Filter(must=[FieldCondition(key="color", match=MatchValue(value="red"))])
        proto_f = to_proto_filter(f)
        @test proto_f isa qdrant.Filter
        @test length(proto_f.must) == 1

        f2 = Filter(must=[FieldCondition(key="tag", match=MatchAny(any=["a", "b"]))])
        proto_f2 = to_proto_filter(f2)
        @test length(proto_f2.must) == 1

        f3 = Filter(must=[FieldCondition(key="n", match=MatchAny(any=[1, 2, 3]))])
        proto_f3 = to_proto_filter(f3)
        @test length(proto_f3.must) == 1

        f4 = Filter(must=[FieldCondition(key="desc", match=MatchText(text="hello"))])
        proto_f4 = to_proto_filter(f4)
        @test length(proto_f4.must) == 1

        f5 = Filter(must=[HasIdCondition(has_id=[1, 2])])
        proto_f5 = to_proto_filter(f5)
        @test length(proto_f5.must) == 1

        f6 = Filter(must=[IsEmptyCondition(is_empty=Dict("key" => "field"))])
        proto_f6 = to_proto_filter(f6)
        @test length(proto_f6.must) == 1

        f7 = Filter(must=[IsNullCondition(is_null=Dict("key" => "field"))])
        proto_f7 = to_proto_filter(f7)
        @test length(proto_f7.must) == 1

        f8 = Filter(
            must=[FieldCondition(key="a", match=MatchValue(value="x"))],
            must_not=[FieldCondition(key="b", match=MatchValue(value="y"))]
        )
        proto_f8 = to_proto_filter(f8)
        @test length(proto_f8.must) == 1
        @test length(proto_f8.must_not) == 1

        f9 = Filter(must=[FieldCondition(key="price",
            range=RangeCondition(gte=10.0, lte=100.0))])
        proto_f9 = to_proto_filter(f9)
        @test length(proto_f9.must) == 1
    end

    # ── WithPayload / WithVectors selectors ─────────────────────────────
    @testset "WithPayload/WithVectors selectors" begin
        @test to_proto_with_payload(nothing) === nothing
        @test to_proto_with_payload(true) isa qdrant.WithPayloadSelector
        @test to_proto_with_payload(false) isa qdrant.WithPayloadSelector
        @test to_proto_with_payload(["field1", "field2"]) isa qdrant.WithPayloadSelector

        @test to_proto_with_vectors(nothing) === nothing
        @test to_proto_with_vectors(true) isa qdrant.WithVectorsSelector
        @test to_proto_with_vectors(false) isa qdrant.WithVectorsSelector
        @test to_proto_with_vectors(["vec1"]) isa qdrant.WithVectorsSelector
    end

    # ── SearchParams conversion ─────────────────────────────────────────
    @testset "SearchParams conversion" begin
        @test to_proto_search_params(nothing) === nothing

        sp = SearchParams(hnsw_ef=128, exact=true)
        proto_sp = to_proto_search_params(sp)
        @test proto_sp isa qdrant.SearchParams

        sp2 = SearchParams(quantization=QuantizationSearchParams(
            ignore=true, rescore=true, oversampling=2.0))
        proto_sp2 = to_proto_search_params(sp2)
        @test proto_sp2.quantization !== nothing
    end

    # ── Points Selector ─────────────────────────────────────────────────
    @testset "Points selector conversion" begin
        sel_ids = to_proto_points_selector([1, 2, 3])
        @test sel_ids isa qdrant.PointsSelector

        sel_single = to_proto_points_selector(42)
        @test sel_single isa qdrant.PointsSelector

        u1, u2 = uuid4(), uuid4()
        sel_uuids = to_proto_points_selector([u1, u2])
        @test sel_uuids isa qdrant.PointsSelector

        f = Filter(must=[FieldCondition(key="k", match=MatchValue(value="v"))])
        sel_filter = to_proto_points_selector(f)
        @test sel_filter isa qdrant.PointsSelector
    end

    # ── VectorParams / Config conversion ────────────────────────────────
    @testset "VectorParams conversion" begin
        vp = VectorParams(size=128, distance=Cosine)
        proto_vp = to_proto_vector_params(vp)
        @test proto_vp isa qdrant.VectorParams
        @test proto_vp.size == 128

        vp2 = VectorParams(size=64, distance=Dot,
            hnsw_config=HnswConfig(m=32, ef_construct=200))
        proto_vp2 = to_proto_vector_params(vp2)
        @test proto_vp2.size == 64
    end

    @testset "VectorsConfig conversion" begin
        vc = to_proto_vectors_config(VectorParams(size=4, distance=Cosine))
        @test vc isa qdrant.VectorsConfig

        named = Dict("text" => VectorParams(size=128, distance=Cosine),
                     "image" => VectorParams(size=256, distance=Dot))
        vc2 = to_proto_vectors_config(named)
        @test vc2 isa qdrant.VectorsConfig
    end

    # ── HNSW / WAL / Optimizers config ──────────────────────────────────
    @testset "Config conversions" begin
        @test to_proto_hnsw_config(nothing) === nothing
        h = HnswConfig(m=16, ef_construct=100)
        @test to_proto_hnsw_config(h) isa qdrant.HnswConfigDiff

        @test to_proto_wal_config(nothing) === nothing
        w = WalConfig(wal_capacity_mb=32)
        @test to_proto_wal_config(w) isa qdrant.WalConfigDiff

        @test to_proto_optimizers_config(nothing) === nothing
        o = OptimizersConfig(default_segment_number=2)
        @test to_proto_optimizers_config(o) isa qdrant.OptimizersConfigDiff
    end

    # ── Ordering conversion ─────────────────────────────────────────────
    @testset "Ordering conversion" begin
        @test to_proto_ordering("weak") isa qdrant.WriteOrdering
        @test to_proto_ordering("medium") isa qdrant.WriteOrdering
        @test to_proto_ordering("strong") isa qdrant.WriteOrdering
    end

end  # gRPC Unit Tests


# ═══════════════════════════════════════════════════════════════════════════
# Integration Tests — require a running Qdrant with gRPC on port 6334
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Integration Tests" begin
    if !grpc_available()
        @warn "Qdrant gRPC not available on port 6334, skipping integration tests"
    else

    # ── Health Check ────────────────────────────────────────────────────
    @testset "Health Check (gRPC)" begin
        result = health_check(GRPC_CONN)
        @test result isa HealthResponse
        @test contains(result.title, "qdrant")
        @test !isempty(result.version)
    end

    # ── Collection Lifecycle ────────────────────────────────────────────
    @testset "Collection Lifecycle (gRPC)" begin
        name = unique_name("grpc_coll")
        try
            config = CollectionConfig(vectors=VectorParams(size=4, distance=Cosine))
            @test create_collection(GRPC_CONN, name, config) === true

            @test collection_exists(GRPC_CONN, name) === true

            colls = list_collections(GRPC_CONN)
            @test colls isa Vector{CollectionDescription}
            @test name in [c.name for c in colls]

            info = get_collection(GRPC_CONN, name)
            @test info !== nothing

            @test delete_collection(GRPC_CONN, name) === true
            @test collection_exists(GRPC_CONN, name) === false
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Points CRUD ─────────────────────────────────────────────────────
    @testset "Points CRUD (gRPC)" begin
        name = unique_name("grpc_pts")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            pts = fixture_points()
            res = upsert_points(GRPC_CONN, name, pts)
            @test res isa UpdateResponse
            @test res.status == "completed"

            cnt = count_points(GRPC_CONN, name; exact=true)
            @test cnt isa CountResponse
            @test cnt.count == 3

            result = get_points(GRPC_CONN, name, [1, 2]; with_payload=true, with_vectors=true)
            @test length(result) == 2
            @test result[1] isa Record
            @test result[1].id in [1, 2]

            scroll_result = scroll_points(GRPC_CONN, name; limit=10, with_payload=true)
            @test scroll_result isa ScrollResponse
            @test length(scroll_result.points) >= 3

            delete_points(GRPC_CONN, name, [3])
            cnt2 = count_points(GRPC_CONN, name; exact=true)
            @test cnt2.count == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Payload Operations ──────────────────────────────────────────────
    @testset "Payload Operations (gRPC)" begin
        name = unique_name("grpc_pay")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            res = set_payload(GRPC_CONN, name,
                Dict{String,Any}("color" => "red"), [1])
            @test res isa UpdateResponse

            pts = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test length(pts) == 1
            @test pts[1].payload["color"] == "red"

            delete_payload(GRPC_CONN, name, ["color"], [1])
            pts2 = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test !haskey(pts2[1].payload, "color")

            clear_payload(GRPC_CONN, name, [2])
            pts3 = get_points(GRPC_CONN, name, [2]; with_payload=true)
            @test pts3[1].payload === nothing || isempty(pts3[1].payload)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Overwrite Payload ───────────────────────────────────────────────
    @testset "Overwrite Payload (gRPC)" begin
        name = unique_name("grpc_overp")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            res = overwrite_payload(GRPC_CONN, name,
                Dict{String,Any}("replaced" => "yes"), [1])
            @test res isa UpdateResponse

            pts = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test pts[1].payload["replaced"] == "yes"
            @test !haskey(pts[1].payload, "group")
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Query Points ────────────────────────────────────────────────────
    @testset "Query Points (gRPC)" begin
        name = unique_name("grpc_query")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            qr = query_points(GRPC_CONN, name,
                QueryRequest(query=Float32[1.0, 0.0, 0.0, 0.0], limit=3))
            @test qr isa QueryResponse
            @test length(qr.points) >= 1
            @test qr.points[1] isa ScoredPoint
            @test qr.points[1].id in [1, 2, 3]

            # Query with filter
            qr2 = query_points(GRPC_CONN, name,
                QueryRequest(
                    query=Float32[1.0, 0.0, 0.0, 0.0],
                    limit=3,
                    filter=Filter(must=[FieldCondition(key="group", match=MatchValue(value="b"))])
                ))
            @test length(qr2.points) >= 1
            @test qr2.points[1].id == 3

            # Query with payload
            qr3 = query_points(GRPC_CONN, name,
                QueryRequest(
                    query=Float32[1.0, 0.0, 0.0, 0.0],
                    limit=2, with_payload=true))
            @test qr3.points[1].payload !== nothing
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Query Batch ─────────────────────────────────────────────────────
    @testset "Query Batch (gRPC)" begin
        name = unique_name("grpc_qbatch")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            qb = query_batch(GRPC_CONN, name, [
                QueryRequest(query=Float32[1, 0, 0, 0], limit=2),
                QueryRequest(query=Float32[0, 1, 0, 0], limit=1),
            ])
            @test length(qb) == 2
            @test qb[1] isa QueryResponse
            @test length(qb[1].points) == 2
            @test length(qb[2].points) == 1
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Scroll with Filter ──────────────────────────────────────────────
    @testset "Scroll with Filter (gRPC)" begin
        name = unique_name("grpc_scroll")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            f = Filter(must=[FieldCondition(key="group", match=MatchValue(value="a"))])
            result = scroll_points(GRPC_CONN, name; filter=f, limit=10, with_payload=true)
            @test result isa ScrollResponse
            @test length(result.points) == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Payload Index ───────────────────────────────────────────────────
    @testset "Payload Index (gRPC)" begin
        name = unique_name("grpc_pidx")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            # Note: gRPC "keyword" maps to proto enum 0 which proto3 skips encoding,
            # so use "integer" for the "n" field
            res = create_payload_index(GRPC_CONN, name, "n"; field_schema="integer")
            @test res isa UpdateResponse

            res2 = delete_payload_index(GRPC_CONN, name, "n")
            @test res2 isa UpdateResponse
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Snapshots ───────────────────────────────────────────────────────
    @testset "Snapshots (gRPC)" begin
        name = unique_name("grpc_snap")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            snap = create_snapshot(GRPC_CONN, name)
            @test snap isa SnapshotInfo

            snaps = list_snapshots(GRPC_CONN, name)
            @test snaps isa Vector{SnapshotInfo}
            @test length(snaps) >= 1

            delete_snapshot(GRPC_CONN, name, snaps[1].name)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Aliases ─────────────────────────────────────────────────────────
    @testset "Aliases (gRPC)" begin
        name = unique_name("grpc_alias")
        alias = unique_name("alias")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            @test create_alias(GRPC_CONN, alias, name) === true

            aliases = list_aliases(GRPC_CONN)
            @test aliases isa Vector{AliasDescription}
            @test any(a.alias_name == alias for a in aliases)

            col_aliases = list_collection_aliases(GRPC_CONN, name)
            @test col_aliases isa Vector{AliasDescription}

            @test delete_alias(GRPC_CONN, alias) === true
        finally
            try; delete_alias(GRPC_CONN, alias); catch; end
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ── Delete by Filter ────────────────────────────────────────────────
    @testset "Delete by Filter (gRPC)" begin
        name = unique_name("grpc_delf")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            f = Filter(must=[FieldCondition(key="group", match=MatchValue(value="b"))])
            res = delete_points(GRPC_CONN, name, f)
            @test res isa UpdateResponse

            cnt = count_points(GRPC_CONN, name; exact=true)
            @test cnt.count == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    # ═══════════════════════════════════════════════════════════════════════
    # HTTP ↔ gRPC Parity Tests
    # ═══════════════════════════════════════════════════════════════════════

    @testset "HTTP ↔ gRPC Parity" begin
        name = unique_name("parity")
        try
            # Create via HTTP, verify via gRPC
            create_collection(HTTP_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            @test collection_exists(GRPC_CONN, name) === true

            # Upsert via HTTP
            upsert_points(HTTP_CONN, name, fixture_points())

            # Count via gRPC
            cnt = count_points(GRPC_CONN, name; exact=true)
            @test cnt.count == 3

            # Query via both, compare results
            http_qr = query_points(HTTP_CONN, name,
                QueryRequest(query=Float32[1.0, 0.0, 0.0, 0.0], limit=3))
            grpc_qr = query_points(GRPC_CONN, name,
                QueryRequest(query=Float32[1.0, 0.0, 0.0, 0.0], limit=3))

            @test length(http_qr.points) == length(grpc_qr.points)
            @test Int(http_qr.points[1].id) == Int(grpc_qr.points[1].id)

            # Upsert via gRPC, read via HTTP
            extra_pt = Point(id=99, vector=Float32[0.5, 0.5, 0.0, 0.0],
                            payload=Dict{String,Any}("source" => "grpc"))
            upsert_points(GRPC_CONN, name, [extra_pt])

            http_pts = get_points(HTTP_CONN, name, [99]; with_payload=true)
            @test length(http_pts) == 1
            @test http_pts[1].payload["source"] == "grpc"

            # Delete via gRPC
            delete_collection(GRPC_CONN, name)
            @test collection_exists(HTTP_CONN, name) === false
        finally
            cleanup_collection(HTTP_CONN, name)
        end
    end

    end  # grpc_available
end  # gRPC Integration Tests
