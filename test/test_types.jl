# ============================================================================
# Unit Tests — Types, Serialization, Connection
# ============================================================================

@testset "Types & Serialization" begin

    @testset "Type Hierarchy" begin
        @test VectorParams <: AbstractConfig
        @test CollectionConfig <: AbstractConfig
        @test CollectionUpdate <: AbstractConfig
        @test HnswConfig <: AbstractConfig
        @test WalConfig <: AbstractConfig
        @test OptimizersConfig <: AbstractConfig
        @test SearchParams <: AbstractConfig
        @test TextIndexParams <: AbstractConfig
        @test LookupLocation <: AbstractConfig
        @test ScalarQuantization <: AbstractConfig
        @test ProductQuantization <: AbstractConfig
        @test BinaryQuantization <: AbstractConfig

        @test QueryRequest <: AbstractQdrantType

        @test Filter <: AbstractCondition
        @test FieldCondition <: AbstractCondition
        @test MatchValue <: AbstractCondition
        @test MatchAny <: AbstractCondition
        @test MatchText <: AbstractCondition
        @test RangeCondition <: AbstractCondition
        @test HasIdCondition <: AbstractCondition

        @test Point <: AbstractQdrantType
        @test NamedVector <: AbstractQdrantType

        @test UpdateResult <: AbstractResponse
        @test CountResult <: AbstractResponse
        @test ScoredPoint <: AbstractResponse
        @test Record <: AbstractResponse
        @test ScrollResult <: AbstractResponse
        @test QueryResult <: AbstractResponse
        @test GroupResult <: AbstractResponse
        @test GroupsResult <: AbstractResponse
        @test SnapshotInfo <: AbstractResponse
        @test CollectionDescription <: AbstractResponse
        @test AliasDescription <: AbstractResponse
        @test HealthInfo <: AbstractResponse
        @test FacetHit <: AbstractResponse
        @test FacetResult <: AbstractResponse
    end

    @testset "Distance Enum" begin
        for d in (Cosine, Euclid, Dot, Manhattan)
            @test d isa Distance
            @test string(d) isa String
        end
    end

    @testset "PointId Type" begin
        @test 42 isa PointId
        @test uuid4() isa PointId
        @test !(1.5 isa PointId)
    end

    @testset "QdrantResponse wrapper" begin
        r = QdrantResponse(true, "ok", 0.01)
        @test r.result === true
        @test r.status == "ok"
        @test r.time ≈ 0.01

        r2 = QdrantResponse(UpdateResult(0, "completed"), "ok", 0.001)
        @test r2.result.operation_id == 0
        @test r2.result.status == "completed"
    end

    @testset "VectorParams serialization" begin
        vp = VectorParams(size=4, distance=Dot)
        parsed = JSON.parse(JSON.json(vp; omit_null=true))
        @test parsed["size"] == 4
        @test parsed["distance"] == "Dot"
        @test !haskey(parsed, "hnsw_config")
    end

    @testset "VectorParams with HnswConfig" begin
        vp = VectorParams(size=4, distance=Euclid,
            hnsw_config=HnswConfig(m=32, ef_construct=200))
        parsed = JSON.parse(JSON.json(vp; omit_null=true))
        @test parsed["hnsw_config"]["m"] == 32
        @test parsed["hnsw_config"]["ef_construct"] == 200
    end

    @testset "CollectionConfig serialization" begin
        cfg = CollectionConfig(vectors=VectorParams(size=128, distance=Cosine))
        parsed = JSON.parse(JSON.json(cfg; omit_null=true))
        @test parsed["vectors"]["size"] == 128
        @test parsed["vectors"]["distance"] == "Cosine"
    end

    @testset "CollectionConfig with sub-configs" begin
        cfg = CollectionConfig(
            vectors=VectorParams(size=4, distance=Dot),
            hnsw_config=HnswConfig(m=16),
            optimizers_config=OptimizersConfig(indexing_threshold=10000),
        )
        parsed = JSON.parse(JSON.json(cfg; omit_null=true))
        @test parsed["hnsw_config"]["m"] == 16
        @test parsed["optimizers_config"]["indexing_threshold"] == 10000
    end

    @testset "Point serialization" begin
        pt = Point(id=1, vector=Float32[1.0, 2.0, 3.0])
        parsed = JSON.parse(JSON.json(pt; omit_null=true))
        @test parsed["id"] == 1
        @test !haskey(parsed, "payload")

        u = uuid4()
        pt2 = Point(id=u, vector=Float32[0.1, 0.2],
                     payload=Dict{String,Any}("color" => "red"))
        parsed2 = JSON.parse(JSON.json(pt2; omit_null=true))
        @test parsed2["id"] == string(u)
        @test parsed2["payload"]["color"] == "red"
    end

    @testset "QueryRequest using_ tag" begin
        qr = QueryRequest(query=Float32[1.0, 0.0], limit=3, using_="image")
        parsed = JSON.parse(JSON.json(qr; omit_null=true))
        @test parsed["using"] == "image"
        @test !haskey(parsed, "using_")
    end

    @testset "Filter serialization" begin
        f = Filter(must=Any[Dict("key" => "color", "match" => Dict("value" => "red"))])
        parsed = JSON.parse(JSON.json(f; omit_null=true, omit_empty=true))
        @test length(parsed["must"]) == 1
        @test !haskey(parsed, "should")
    end

    @testset "serialize_body" begin
        s = serialize_body(VectorParams(size=4, distance=Dot))
        @test s isa String
        parsed = JSON.parse(s)
        @test parsed["size"] == 4
        @test !haskey(parsed, "hnsw_config")

        d = Dict("a" => 1, "b" => nothing, "c" => [], "d" => "x")
        pd = JSON.parse(serialize_body(d))
        @test pd["a"] == 1
        @test !haskey(pd, "b")
        @test !haskey(pd, "c")
    end

    @testset "QdrantClient" begin
        client = QdrantClient()
        @test client isa QdrantClient{HTTPTransport}
        @test client.transport.host == "localhost"
        @test client.transport.port == 6333

        conn2 = QdrantClient(host="example.com", port=8080, api_key="secret", tls=true)
        @test conn2.transport.host == "example.com"
        @test conn2.transport.api_key == "secret"
        @test conn2.transport.tls === true
    end

    @testset "Transport" begin
        t = HTTPTransport(host="myhost", port=9999, tls=true)
        @test Qdrant.base_url(t) == "https://myhost:9999"

        t2 = HTTPTransport(host="local", port=6333)
        @test Qdrant.transport_url(t2, "/collections") == "http://local:6333/collections"
        @test Qdrant.transport_url(t2, "collections") == "http://local:6333/collections"
    end

    @testset "Headers" begin
        t = HTTPTransport(api_key="secret")
        hd = Dict(Qdrant.transport_headers(t))
        @test hd["Content-Type"] == "application/json"
        @test hd["api-key"] == "secret"

        t2 = HTTPTransport()
        hd2 = Dict(Qdrant.transport_headers(t2))
        @test !haskey(hd2, "api-key")
    end

    @testset "Global client" begin
        c1 = QdrantClient(host="host1")
        set_client!(c1)
        @test get_client().transport.host == "host1"
        set_client!(QdrantClient())
        @test get_client().transport.host == "localhost"
    end

    @testset "QdrantError" begin
        err = QdrantError(404, "Not found")
        @test err.status == 404
        @test err.detail === nothing

        buf = IOBuffer()
        showerror(buf, err)
        @test contains(String(take!(buf)), "404")
    end
end
