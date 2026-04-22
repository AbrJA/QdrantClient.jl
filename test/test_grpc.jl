# ============================================================================
# gRPC Tests for Qdrant.jl v1.0
# ============================================================================

using Qdrant: qdrant, to_proto_point_id, from_proto_point_id,
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

const GRPC_CONN = QdrantClient(GRPCTransport())
const HTTP_CONN = QdrantClient()

function grpc_available(client::QdrantClient=GRPC_CONN)
    try; health_check(client); true; catch; false; end
end

# ═══════════════════════════════════════════════════════════════════════════
# Unit Tests — Type Conversions (no server required)
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Unit Tests" begin

    @testset "GRPCTransport construction" begin
        t = GRPCTransport()
        @test t.host == "localhost"
        @test t.port == 6334
        @test t.api_key === nothing
        @test t.tls == false

        t2 = GRPCTransport(host="qdrant.example.com", port=6335, tls=true, api_key="secret")
        @test t2.host == "qdrant.example.com"
        @test t2.tls == true
    end

    @testset "PointId conversion" begin
        pid_int = to_proto_point_id(42)
        @test from_proto_point_id(pid_int) == 42

        u = uuid4()
        pid_uuid = to_proto_point_id(u)
        @test from_proto_point_id(pid_uuid) == u
    end

    @testset "Distance conversion" begin
        for d in (Cosine, Euclid, Dot, Manhattan)
            @test from_proto_distance(to_proto_distance(d)) === d
        end
    end

    @testset "Value conversion roundtrips" begin
        for v in (nothing, true, false, 42, 0, -100, "hello", "", [1,2,3], ["a","b"])
            @test proto_value_to_julia(julia_value_to_proto(v)) == v
        end
        @test proto_value_to_julia(julia_value_to_proto(3.14)) ≈ 3.14

        d = Dict("a" => 1, "b" => "two")
        result = proto_value_to_julia(julia_value_to_proto(d))
        @test result["a"] == 1 && result["b"] == "two"
    end

    @testset "Payload conversion" begin
        payload = Dict{String,Any}("name" => "test", "count" => 5, "tags" => ["a", "b"])
        result = from_proto_payload(to_proto_payload(payload))
        @test result["name"] == "test"
        @test result["tags"] == ["a", "b"]
        @test to_proto_payload(nothing) == Dict{String,qdrant.Value}()
    end

    @testset "Vector conversion" begin
        v = Float32[1.0, 2.0, 3.0, 4.0]
        @test to_proto_vectors(v).vectors_options.name === :vector

        nv = NamedVector(name="image", vector=Float32[1.0, 0.0])
        @test to_proto_vectors(nv).vectors_options.name === :vectors

        dv = Dict("text" => Float32[1.0, 0.0], "image" => Float32[0.0, 1.0])
        @test to_proto_vectors(dv).vectors_options.name === :vectors
    end

    @testset "Point conversion" begin
        p = Point(id=42, vector=Float32[1, 0, 0, 0], payload=Dict{String,Any}("k" => "v"))
        proto_p = to_proto_point(p)
        @test proto_p isa qdrant.PointStruct
        @test from_proto_point_id(proto_p.id) == 42
    end

    @testset "Filter conversion" begin
        @test to_proto_filter(nothing) === nothing

        f = Filter(must=[FieldCondition(key="color", match=MatchValue(value="red"))])
        @test to_proto_filter(f) isa qdrant.Filter

        for cond in [
            FieldCondition(key="tag", match=MatchAny(any=["a", "b"])),
            FieldCondition(key="n", match=MatchAny(any=[1, 2])),
            FieldCondition(key="desc", match=MatchText(text="hello")),
            FieldCondition(key="price", range=RangeCondition(gte=10.0, lte=100.0)),
        ]
            @test length(to_proto_filter(Filter(must=[cond])).must) == 1
        end

        for cond in [HasIdCondition(has_id=[1, 2]),
                     IsEmptyCondition(is_empty=Dict("key" => "field")),
                     IsNullCondition(is_null=Dict("key" => "field"))]
            @test length(to_proto_filter(Filter(must=[cond])).must) == 1
        end
    end

    @testset "WithPayload/WithVectors selectors" begin
        @test to_proto_with_payload(nothing) === nothing
        @test to_proto_with_payload(true) isa qdrant.WithPayloadSelector
        @test to_proto_with_vectors(["vec1"]) isa qdrant.WithVectorsSelector
    end

    @testset "SearchParams conversion" begin
        @test to_proto_search_params(nothing) === nothing
        sp = SearchParams(hnsw_ef=128, exact=true)
        @test to_proto_search_params(sp) isa qdrant.SearchParams
    end

    @testset "Points selector conversion" begin
        @test to_proto_points_selector([1, 2, 3]) isa qdrant.PointsSelector
        @test to_proto_points_selector(42) isa qdrant.PointsSelector
        f = Filter(must=[FieldCondition(key="k", match=MatchValue(value="v"))])
        @test to_proto_points_selector(f) isa qdrant.PointsSelector
    end

    @testset "VectorParams conversion" begin
        vp = VectorParams(size=128, distance=Cosine)
        @test to_proto_vector_params(vp).size == 128

        vc = to_proto_vectors_config(VectorParams(size=4, distance=Cosine))
        @test vc isa qdrant.VectorsConfig
    end

    @testset "Config conversions" begin
        @test to_proto_hnsw_config(nothing) === nothing
        @test to_proto_hnsw_config(HnswConfig(m=16)) isa qdrant.HnswConfigDiff
        @test to_proto_wal_config(nothing) === nothing
        @test to_proto_wal_config(WalConfig(wal_capacity_mb=32)) isa qdrant.WalConfigDiff
        @test to_proto_optimizers_config(nothing) === nothing
        @test to_proto_optimizers_config(OptimizersConfig(default_segment_number=2)) isa qdrant.OptimizersConfigDiff
    end

    @testset "Ordering conversion" begin
        for o in ("weak", "medium", "strong")
            @test to_proto_ordering(o) isa qdrant.WriteOrdering
        end
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# gRPC Integration Tests
# ═══════════════════════════════════════════════════════════════════════════

@testset "gRPC Integration Tests" begin
    if !grpc_available()
        @warn "Qdrant gRPC not available on port 6334, skipping"
    else

    @testset "Health Check (gRPC)" begin
        result = health_check(GRPC_CONN)
        @test result isa QdrantResponse{HealthInfo}
        @test contains(result.result.title, "qdrant")
    end

    @testset "Collection Lifecycle (gRPC)" begin
        name = unique_name("grpc_coll")
        try
            config = CollectionConfig(vectors=VectorParams(size=4, distance=Cosine))
            @test create_collection(GRPC_CONN, name, config).result === true
            @test collection_exists(GRPC_CONN, name).result === true

            colls = list_collections(GRPC_CONN)
            @test name in [c.name for c in colls.result]

            @test delete_collection(GRPC_CONN, name).result === true
            @test collection_exists(GRPC_CONN, name).result === false
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Points CRUD (gRPC)" begin
        name = unique_name("grpc_pts")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

            res = upsert_points(GRPC_CONN, name, fixture_points())
            @test res isa QdrantResponse{UpdateResult}
            @test res.result.status == "completed"

            cnt = count_points(GRPC_CONN, name; exact=true)
            @test cnt.result.count == 3

            got = get_points(GRPC_CONN, name, [1, 2]; with_payload=true, with_vectors=true)
            @test length(got.result) == 2
            @test got.result[1] isa Record

            sr = scroll_points(GRPC_CONN, name; limit=10, with_payload=true)
            @test sr isa QdrantResponse{ScrollResult}
            @test length(sr.result.points) >= 3

            delete_points(GRPC_CONN, name, [3])
            @test count_points(GRPC_CONN, name; exact=true).result.count == 2
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Payload Operations (gRPC)" begin
        name = unique_name("grpc_pay")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            set_payload(GRPC_CONN, name, Dict{String,Any}("color" => "red"), [1])
            pts = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test pts.result[1].payload["color"] == "red"

            delete_payload(GRPC_CONN, name, ["color"], [1])
            pts2 = get_points(GRPC_CONN, name, [1]; with_payload=true)
            @test !haskey(pts2.result[1].payload, "color")

            clear_payload(GRPC_CONN, name, [2])
            pts3 = get_points(GRPC_CONN, name, [2]; with_payload=true)
            @test pts3.result[1].payload === nothing || isempty(pts3.result[1].payload)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Query Points (gRPC)" begin
        name = unique_name("grpc_query")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            qr = query_points(GRPC_CONN, name,
                QueryRequest(query=Float32[1, 0, 0, 0], limit=3))
            @test qr isa QdrantResponse{QueryResult}
            @test length(qr.result.points) >= 1
            @test qr.result.points[1] isa ScoredPoint

            qr2 = query_points(GRPC_CONN, name,
                QueryRequest(query=Float32[1, 0, 0, 0], limit=2, with_payload=true))
            @test qr2.result.points[1].payload !== nothing

            qb = query_batch(GRPC_CONN, name, [
                QueryRequest(query=Float32[1, 0, 0, 0], limit=2),
                QueryRequest(query=Float32[0, 1, 0, 0], limit=1),
            ])
            @test length(qb.result) == 2
            @test length(qb.result[1].points) == 2

            qg = query_groups(GRPC_CONN, name, QueryRequest(
                query=Float32[1, 0, 0, 0],
                limit=10,
                group_by="group",
                group_size=3,
                with_payload=true,
            ))
            @test qg isa QdrantResponse{GroupsResult}
            @test length(qg.result.groups) >= 1
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Aliases (gRPC)" begin
        name = unique_name("grpc_alias")
        alias = unique_name("alias")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            @test create_alias(GRPC_CONN, alias, name).result === true

            aliases = list_aliases(GRPC_CONN)
            @test any(a.alias_name == alias for a in aliases.result)

            @test delete_alias(GRPC_CONN, alias).result === true
        finally
            try; delete_alias(GRPC_CONN, alias); catch; end
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Snapshots (gRPC)" begin
        name = unique_name("grpc_snap")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            snap = create_snapshot(GRPC_CONN, name)
            @test snap isa QdrantResponse{SnapshotInfo}

            snaps = list_snapshots(GRPC_CONN, name)
            @test length(snaps.result) >= 1

            delete_snapshot(GRPC_CONN, name, snaps.result[1].name)
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "Payload Index (gRPC)" begin
        name = unique_name("grpc_pidx")
        try
            create_collection(GRPC_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            upsert_points(GRPC_CONN, name, fixture_points())

            res = create_payload_index(GRPC_CONN, name, "n"; field_schema="integer")
            @test res isa QdrantResponse{UpdateResult}

            res2 = delete_payload_index(GRPC_CONN, name, "n")
            @test res2 isa QdrantResponse{UpdateResult}
        finally
            cleanup_collection(GRPC_CONN, name)
        end
    end

    @testset "HTTP ↔ gRPC Parity" begin
        name = unique_name("parity")
        try
            create_collection(HTTP_CONN, name,
                CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
            @test collection_exists(GRPC_CONN, name).result === true

            upsert_points(HTTP_CONN, name, fixture_points())
            @test count_points(GRPC_CONN, name; exact=true).result.count == 3

            http_qr = query_points(HTTP_CONN, name,
                QueryRequest(query=Float32[1, 0, 0, 0], limit=3))
            grpc_qr = query_points(GRPC_CONN, name,
                QueryRequest(query=Float32[1, 0, 0, 0], limit=3))
            @test length(http_qr.result.points) == length(grpc_qr.result.points)

            extra = Point(id=99, vector=Float32[0.5, 0.5, 0, 0],
                         payload=Dict{String,Any}("source" => "grpc"))
            upsert_points(GRPC_CONN, name, [extra])
            http_pts = get_points(HTTP_CONN, name, [99]; with_payload=true)
            @test http_pts.result[1].payload["source"] == "grpc"

            delete_collection(GRPC_CONN, name)
            @test collection_exists(HTTP_CONN, name).result === false
        finally
            cleanup_collection(HTTP_CONN, name)
        end
    end

    end  # grpc_available
end  # gRPC Integration Tests
