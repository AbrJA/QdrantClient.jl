using Test
using UUIDs
using HTTP
using JSON
using QdrantClient

const TEST_CLIENT = Client(host="http://localhost", port=6333)

function test_collection_name(prefix::String)
    return string(prefix, "_", replace(string(uuid4()), "-" => ""))
end

function qdrant_available(client::Client=TEST_CLIENT)
    try
        collections(client)
        return true
    catch
        return false
    end
end

function cleanup_collection(client::Client, name::String)
    try
        delete_collection(client, name)
    catch
    end
end

function cleanup_alias(client::Client, name::String)
    try
        delete_alias(client, name)
    catch
    end
end

function fixture_points()
    return [
        PointStruct(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0], payload=Dict("group" => "a", "n" => 1)),
        PointStruct(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0], payload=Dict("group" => "a", "n" => 2)),
        PointStruct(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0], payload=Dict("group" => "b", "n" => 3)),
    ]
end

@testset "QdrantClient" begin
    @testset "Client Basics" begin
        client = Client()
        @test client.host == "http://localhost"
        @test client.port == 6333
        @test isnothing(client.api_key)

        custom = Client(host="http://example.com", port=8000, api_key="test-key")
        @test custom.host == "http://example.com"
        @test custom.port == 8000
        @test custom.api_key == "test-key"

        set_global_client(custom)
        @test get_global_client().host == "http://example.com"
        set_global_client(Client())

        @test QdrantClient._make_url(client, "/collections") == "http://localhost:6333/collections"
        @test QdrantClient._make_url(client, "collections") == "http://localhost:6333/collections"
    end

    @testset "Headers And Serialization" begin
        headers = QdrantClient._make_headers(Client(api_key="secret"))
        @test headers["Content-Type"] == "application/json"
        @test headers["User-Agent"] == "QdrantClient.jl/0.1.0"
        @test headers["api-key"] == "secret"

        nested = CollectionConfig(vectors=VectorParams(size=4, distance="Dot"))
        encoded = QdrantClient._struct_to_dict(nested)
        @test encoded[:vectors][:size] == 4
        @test encoded[:vectors][:distance] == "Dot"

        updated = CollectionUpdate(params=Dict("on_disk_payload" => true))
        update_dict = QdrantClient._struct_to_dict(updated)
        @test update_dict[:params]["on_disk_payload"] === true

        search_request = SearchRequest(vector=Float32[1, 0, 0, 0], limit=3, with_payload=true)
        search_dict = QdrantClient._struct_to_dict(search_request)
        @test search_dict[:limit] == 3
        @test search_dict[:with_payload] === true
    end

    @testset "Error And Parsing" begin
        err = QdrantClient.qdrant_error(404, "Collection not found")
        @test err.status == 404
        @test err.message == "Collection not found"
        @test isnothing(err.detail)

        api_error = HTTP.Response(404, "", body=JSON.json(Dict(
            :status => Dict(:error => "missing"),
            :result => nothing,
            :time => 0.0,
        )))
        converted = QdrantClient.api_error_response(api_error)
        @test converted.status == 404
        @test converted.message == "missing"

        empty_response = HTTP.Response(200, "", body="")
        @test isnothing(QdrantClient._parse_response(empty_response, Dict))

        wrapped = HTTP.Response(200, "", body=JSON.json(Dict(
            :status => "ok",
            :time => 0.01,
            :result => Dict(:count => 7),
        )))
        parsed = QdrantClient._parse_response(wrapped, Dict)
        @test parsed[:count] == 7

        raw = HTTP.Response(200, "", body=JSON.json(Dict(:key => :value)))
        @test QdrantClient._parse_response(raw, Dict)[:key] == "value"
    end

    @testset "Type Definitions" begin
        params = VectorParams(size=128, distance="Cosine")
        @test params.size == 128
        @test params.distance == "Cosine"

        point = PointStruct(id=1, vector=rand(Float32, 8), payload=Dict("label" => "test"))
        @test point.id == 1
        @test length(point.vector) == 8
        @test point.payload["label"] == "test"

        search_req = SearchRequest(vector=rand(Float32, 8), limit=10)
        @test search_req.limit == 10
        @test length(search_req.vector) == 8
    end

    @testset "Integration" begin
        if !qdrant_available()
            @test_skip "Live Qdrant server not available on localhost:6333"
        else
            @testset "Collection Lifecycle" begin
                client = TEST_CLIENT
                collection = test_collection_name("julia_collection")
                alias_1 = collection * "_alias"
                alias_2 = collection * "_alias_renamed"

                cleanup_alias(client, alias_1)
                cleanup_alias(client, alias_2)
                cleanup_collection(client, collection)

                @test create_collection(client, collection; vectors=VectorParams(size=4, distance="Dot")) === true

                all_collections = collections(client)
                @test any(item[:name] == collection for item in all_collections[:collections])

                exists = collection_exists(client, collection)
                @test exists[:exists] === true

                info = get_collection_info(client, collection)
                @test info[:status] == "green"
                @test info[:config][:params][:vectors][:size] == 4

                @test create_alias(client, alias_1, collection) === true

                aliases = list_aliases(client)
                @test any(item[:alias_name] == alias_1 for item in aliases[:aliases])

                collection_aliases = list_collection_aliases(client, collection)
                @test any(item[:alias_name] == alias_1 for item in collection_aliases[:aliases])

                @test rename_alias(client, alias_1, alias_2) === true
                aliases_after_rename = list_aliases(client)
                @test any(item[:alias_name] == alias_2 for item in aliases_after_rename[:aliases])

                @test delete_alias(client, alias_2) === true
                @test delete_collection(client, collection) === true
            end

            @testset "Points CRUD And Payload" begin
                client = TEST_CLIENT
                collection = test_collection_name("julia_points")
                cleanup_collection(client, collection)

                create_collection(client, collection; vectors=VectorParams(size=4, distance="Dot"))
                points = fixture_points()

                upsert_result = upsert_points(client, collection, points; wait=true)
                @test upsert_result[:status] == "completed"

                retrieved = retrieve_points(client, collection, [1, 2]; with_vectors=true, with_payload=true)
                @test length(retrieved) == 2
                @test retrieved[1][:id] == 1
                @test retrieved[1][:payload][:group] == "a"
                @test length(retrieved[1][:vector]) == 4

                single_retrieved = retrieve_points(client, collection, 1; with_payload=true)
                @test length(single_retrieved) == 1
                @test single_retrieved[1][:id] == 1

                counted = count_points(client, collection; exact=true)
                @test counted[:count] == 3

                set_result = set_payload(client, collection, Dict("flag" => true), [1, 2]; wait=true)
                @test set_result[:status] == "completed"

                single_set_result = set_payload(client, collection, Dict("single_flag" => true), 1; wait=true)
                @test single_set_result[:status] == "completed"

                after_set = retrieve_points(client, collection, [1, 2]; with_payload=true)
                @test after_set[1][:payload][:flag] === true
                @test after_set[2][:payload][:flag] === true
                @test after_set[1][:payload][:single_flag] === true

                delete_payload_result = delete_payload(client, collection, ["flag"], [2]; wait=true)
                @test delete_payload_result[:status] == "completed"

                single_delete_payload_result = delete_payload(client, collection, ["single_flag"], 1; wait=true)
                @test single_delete_payload_result[:status] == "completed"

                after_delete_payload = retrieve_points(client, collection, [2]; with_payload=true)
                @test !haskey(after_delete_payload[1][:payload], :flag)

                after_single_delete_payload = retrieve_points(client, collection, 1; with_payload=true)
                @test !haskey(after_single_delete_payload[1][:payload], :single_flag)

                clear_result = clear_payload(client, collection, 3; wait=true)
                @test clear_result[:status] == "completed"

                after_clear = retrieve_points(client, collection, [3]; with_payload=true)
                @test isempty(after_clear[1][:payload])

                deleted = delete_points(client, collection, 2; wait=true)
                @test deleted[:status] == "completed"

                remaining = count_points(client, collection; exact=true)
                @test remaining[:count] == 2

                cleanup_collection(client, collection)
            end

            @testset "Search Query And Discovery" begin
                client = TEST_CLIENT
                collection = test_collection_name("julia_query")
                cleanup_collection(client, collection)

                create_collection(client, collection; vectors=VectorParams(size=4, distance="Dot"))
                upsert_points(client, collection, fixture_points(); wait=true)

                scrolled = scroll_points(client, collection; limit=10, with_payload=true)
                @test length(scrolled[:points]) == 3
                @test isnothing(scrolled[:next_page_offset])

                search_request = SearchRequest(vector=Float32[1, 0, 0, 0], limit=2, with_payload=true)
                search_hits = search_points(client, collection, search_request)
                @test length(search_hits) == 2
                @test search_hits[1][:id] == 1

                search_hits_batch = search_batch(client, collection, [search_request])
                @test length(search_hits_batch) == 1
                @test length(search_hits_batch[1]) == 2

                recommend_request = RecommendRequest(positive=[1], limit=2, with_payload=true)
                recommendations = recommend_points(client, collection, recommend_request)
                @test length(recommendations) == 2
                @test recommendations[1][:id] != 1

                query_request = QueryRequest(query=Float32[1, 0, 0, 0], limit=2, with_payload=true)
                query_result = query_points(client, collection, query_request)
                @test length(query_result[:points]) == 2
                @test query_result[:points][1][:id] == 1

                query_batch_result = query_batch(client, collection, [query_request])
                @test length(query_batch_result) == 1
                @test length(query_batch_result[1][:points]) == 2

                discovered = discover_points(client, collection, DiscoverRequest(target=1, limit=2, with_payload=true))
                @test length(discovered) == 2
                @test discovered[1][:id] != 1

                cleanup_collection(client, collection)
            end

            @testset "Snapshots" begin
                client = TEST_CLIENT
                collection = test_collection_name("julia_snapshot")
                cleanup_collection(client, collection)

                create_collection(client, collection; vectors=VectorParams(size=4, distance="Dot"))
                upsert_points(client, collection, fixture_points(); wait=true)

                snapshot = create_snapshot(client, collection)
                @test haskey(snapshot, :name)

                snapshots = list_snapshots(client, collection)
                @test length(snapshots) >= 1
                @test any(item[:name] == snapshot[:name] for item in snapshots)

                deleted = delete_snapshot(client, collection, snapshot[:name])
                @test deleted === true

                cleanup_collection(client, collection)
            end
        end
    end
end

