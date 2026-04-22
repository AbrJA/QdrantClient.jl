# ============================================================================
# Integration Tests — HTTP transport
# ============================================================================

@testset "HTTP Integration" begin
    if !qdrant_available()
        @warn "Qdrant not available on localhost:6333 — skipping"
        @test_skip "Qdrant not available"
    else

    @testset "Collection Lifecycle" begin
        name = unique_name("coll")
        cleanup_collection(CONN, name)

        resp = create_collection(CONN, name,
            CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        @test resp isa QdrantResponse{Bool}
        @test resp.result === true
        @test resp.status == "ok"
        @test resp.time >= 0.0

        colls = list_collections(CONN)
        @test colls isa QdrantResponse{Vector{CollectionDescription}}
        @test name in [c.name for c in colls.result]

        exists = collection_exists(CONN, name)
        @test exists.result === true

        info = get_collection(CONN, name)
        @test info.result["status"] == "green"

        @test delete_collection(CONN, name).result === true
    end

    @testset "Collection create kwargs" begin
        name = unique_name("ckw")
        cleanup_collection(CONN, name)
        create_collection(CONN, name; vectors=VectorParams(size=4, distance=Cosine))
        info = get_collection(CONN, name)
        @test info.result["config"]["params"]["vectors"]["distance"] == "Cosine"
        cleanup_collection(CONN, name)
    end

    @testset "Collection with typed configs" begin
        name = unique_name("cfg")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(
            vectors=VectorParams(size=4, distance=Dot),
            hnsw_config=HnswConfig(m=32, ef_construct=200),
            optimizers_config=OptimizersConfig(indexing_threshold=10000),
        ))
        info = get_collection(CONN, name)
        @test info.result["config"]["hnsw_config"]["m"] == 32
        @test info.result["config"]["optimizer_config"]["indexing_threshold"] == 10000
        cleanup_collection(CONN, name)
    end

    @testset "Aliases" begin
        name = unique_name("alias")
        a1, a2 = name * "_a1", name * "_a2"
        cleanup_alias(CONN, a1); cleanup_alias(CONN, a2)
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

        @test create_alias(CONN, a1, name).result === true
        aliases = list_aliases(CONN)
        @test a1 in [a.alias_name for a in aliases.result]

        ca = list_collection_aliases(CONN, name)
        @test any(a.alias_name == a1 for a in ca.result)

        @test rename_alias(CONN, a1, a2).result === true
        @test delete_alias(CONN, a2).result === true
        cleanup_collection(CONN, name)
    end

    @testset "Points CRUD" begin
        name = unique_name("pts")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))

        res = upsert_points(CONN, name, fixture_points(); wait=true)
        @test res isa QdrantResponse{UpdateResult}
        @test res.result.status == "completed"
        @test res.status == "ok"
        @test res.time >= 0.0

        got = get_points(CONN, name, [1, 2]; with_vectors=true, with_payload=true)
        @test length(got.result) == 2
        @test got.result[1] isa Record
        @test got.result[1].id == 1
        @test got.result[1].payload["group"] == "a"

        rec = get_point(CONN, name, 1)
        @test rec.result isa Record
        @test rec.result.id == 1

        cnt = count_points(CONN, name; exact=true)
        @test cnt.result.count == 3

        delete_points(CONN, name, [2]; wait=true)
        @test count_points(CONN, name; exact=true).result.count == 2

        cleanup_collection(CONN, name)
    end

    @testset "Points UUID IDs" begin
        name = unique_name("uuid")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        u1 = uuid4()
        pts = [Point(id=u1, vector=Float32[1, 0, 0, 0],
                     payload=Dict{String,Any}("label" => "first"))]
        upsert_points(CONN, name, pts; wait=true)
        got = get_points(CONN, name, [u1]; with_payload=true)
        @test string(got.result[1].id) == string(u1)
        @test got.result[1].payload["label"] == "first"
        cleanup_collection(CONN, name)
    end

    @testset "Payload Operations" begin
        name = unique_name("pay")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)

        set_payload(CONN, name, Dict("flag" => true), [1, 2])
        after = get_points(CONN, name, [1, 2]; with_payload=true)
        @test after.result[1].payload["flag"] === true

        overwrite_payload(CONN, name, Dict("new" => "only"), [1])
        p1 = get_points(CONN, name, [1]; with_payload=true)
        @test p1.result[1].payload["new"] == "only"
        @test !haskey(p1.result[1].payload, "group")

        delete_payload(CONN, name, ["flag"], [2])
        p2 = get_points(CONN, name, [2]; with_payload=true)
        @test !haskey(p2.result[1].payload, "flag")

        clear_payload(CONN, name, [3]; wait=true)
        p3 = get_points(CONN, name, [3]; with_payload=true)
        @test isempty(p3.result[1].payload)

        cleanup_collection(CONN, name)
    end

    @testset "Scroll & Count" begin
        name = unique_name("scroll")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)

        sr = scroll_points(CONN, name; limit=10, with_payload=true)
        @test sr isa QdrantResponse{ScrollResult}
        @test length(sr.result.points) == 3

        sr2 = scroll_points(CONN, name; limit=2)
        @test length(sr2.result.points) == 2
        @test sr2.result.next_page_offset !== nothing

        cleanup_collection(CONN, name)
    end

    @testset "Query Points" begin
        name = unique_name("query")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)

        qr = query_points(CONN, name; query=Float32[1, 0, 0, 0], limit=2, with_payload=true)
        @test qr isa QdrantResponse{QueryResult}
        @test length(qr.result.points) == 2
        @test qr.result.points[1] isa ScoredPoint
        @test qr.result.points[1].id == 1
        @test qr.time >= 0.0

        qb = query_batch(CONN, name, [
            QueryRequest(query=Float32[1, 0, 0, 0], limit=2),
            QueryRequest(query=Float32[0, 1, 0, 0], limit=1),
        ])
        @test length(qb.result) == 2
        @test length(qb.result[1].points) == 2

        cleanup_collection(CONN, name)
    end

    @testset "Query with SearchParams" begin
        name = unique_name("qparams")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)
        qr = query_points(CONN, name, QueryRequest(
            query=Float32[1, 0, 0, 0], limit=2, params=SearchParams(exact=true)))
        @test length(qr.result.points) == 2
        cleanup_collection(CONN, name)
    end

    @testset "Snapshots" begin
        name = unique_name("snap")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)

        snap = create_snapshot(CONN, name)
        @test snap isa QdrantResponse{SnapshotInfo}
        @test !isempty(snap.result.name)

        snaps = list_snapshots(CONN, name)
        @test snap.result.name in [s.name for s in snaps.result]

        @test delete_snapshot(CONN, name, snap.result.name).result === true
        cleanup_collection(CONN, name)
    end

    @testset "Payload Index" begin
        name = unique_name("pidx")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)

        res = create_payload_index(CONN, name, "group"; field_schema="keyword", wait=true)
        @test res.result.status == "completed"

        tip = TextIndexParams(tokenizer="word", lowercase=true)
        res2 = create_payload_index(CONN, name, "n"; field_schema="integer", wait=true)
        @test res2.result.status == "completed"

        @test delete_payload_index(CONN, name, "group"; wait=true).result.status == "completed"
        cleanup_collection(CONN, name)
    end

    @testset "Batch Points" begin
        name = unique_name("batch")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        ops = [Dict("upsert" => Dict("points" => [
            Dict("id" => 1, "vector" => Float32[1, 0, 0, 0]),
            Dict("id" => 2, "vector" => Float32[0, 1, 0, 0]),
        ]))]
        res = batch_points(CONN, name, ops; wait=true)
        @test res.result isa Vector{UpdateResult}
        @test count_points(CONN, name; exact=true).result.count == 2
        cleanup_collection(CONN, name)
    end

    @testset "Update Collection" begin
        name = unique_name("upd")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        resp = update_collection(CONN, name,
            CollectionUpdate(optimizers_config=OptimizersConfig(indexing_threshold=10000)))
        @test resp.result === true
        cleanup_collection(CONN, name)
    end

    @testset "Service API" begin
        health = health_check(CONN)
        @test health isa QdrantResponse{HealthInfo}
        @test contains(health.result.title, "qdrant")
        @test !isempty(health.result.version)

        ver = get_version(CONN)
        @test ver.result.version == health.result.version

        @test get_telemetry(CONN).result isa AbstractDict
        @test get_metrics(CONN).result isa String
    end

    @testset "Cluster Status" begin
        cs = cluster_status(CONN)
        @test cs.result isa AbstractDict
    end

    @testset "Facet" begin
        name = unique_name("facet")
        cleanup_collection(CONN, name)
        create_collection(CONN, name, CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
        upsert_points(CONN, name, fixture_points(); wait=true)
        create_payload_index(CONN, name, "group"; field_schema="keyword", wait=true)

        fr = facet(CONN, name, "group")
        @test fr isa QdrantResponse{FacetResult}
        @test length(fr.result.hits) >= 1
        cleanup_collection(CONN, name)
    end

    end # qdrant_available
end # HTTP Integration
