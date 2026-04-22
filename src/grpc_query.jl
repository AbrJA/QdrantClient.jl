# ============================================================================
# Query API — gRPC transport
# ============================================================================

# ── Query Points ─────────────────────────────────────────────────────────

function query_points(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                      req::QueryRequest)
    proto_req = qdrant.QueryPoints(
        collection,
        qdrant.PrefetchQuery[],
        _build_grpc_query(req.query),
        req.using_ !== nothing ? req.using_ : "",
        to_proto_filter(req.filter),
        to_proto_search_params(req.params),
        req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
        req.limit !== nothing ? UInt64(req.limit) : UInt64(10),
        req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
        to_proto_with_vectors(req.with_vector),
        to_proto_with_payload(req.with_payload),
        nothing, nothing, nothing, UInt64(0),
    )
    resp = grpc_request(client.transport, Points_Query_Client, proto_req)
    points = ScoredPoint[_grpc_to_scored(sp) for sp in resp.result]
    QdrantResponse(QueryResult(points), "ok", resp.time)
end

function _build_grpc_query(::Nothing)
    nothing
end
function _build_grpc_query(q::AbstractVector{<:AbstractFloat})
    dense = qdrant.DenseVector(Float32.(q))
    vi = qdrant.VectorInput(OneOf(:dense, dense))
    qdrant.Query(OneOf(:nearest, vi))
end
function _build_grpc_query(q::String)
    qdrant.Query(OneOf(:order_by, qdrant.OrderBy(q, qdrant.Direction.Asc, nothing)))
end
function _build_grpc_query(::AbstractDict)
    nothing  # Complex dict queries not yet mapped to gRPC proto
end

# ── Query Batch ──────────────────────────────────────────────────────────

function query_batch(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                     requests::AbstractVector{QueryRequest})
    query_list = qdrant.QueryPoints[]
    for req in requests
        push!(query_list, qdrant.QueryPoints(
            collection, qdrant.PrefetchQuery[],
            _build_grpc_query(req.query),
            req.using_ !== nothing ? req.using_ : "",
            to_proto_filter(req.filter),
            to_proto_search_params(req.params),
            req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
            req.limit !== nothing ? UInt64(req.limit) : UInt64(10),
            req.offset !== nothing ? UInt64(req.offset) : UInt64(0),
            to_proto_with_vectors(req.with_vector),
            to_proto_with_payload(req.with_payload),
            nothing, nothing, nothing, UInt64(0),
        ))
    end
    proto_req = qdrant.QueryBatchPoints(collection, query_list, nothing, UInt64(0))
    resp = grpc_request(client.transport, Points_QueryBatch_Client, proto_req)
    results = QueryResult[QueryResult(ScoredPoint[_grpc_to_scored(sp) for sp in batch.result])
                          for batch in resp.result]
    QdrantResponse(results, "ok", resp.time)
end

# ── Query Groups ─────────────────────────────────────────────────────────

function query_groups(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                      req::QueryRequest)
    proto_req = qdrant.QueryPointGroups(
        collection,
        qdrant.PrefetchQuery[],
        _build_grpc_query(req.query),
        req.using_ !== nothing ? req.using_ : "",
        to_proto_filter(req.filter),
        to_proto_search_params(req.params),
        req.score_threshold !== nothing ? Float32(req.score_threshold) : Float32(0),
        to_proto_with_payload(req.with_payload),
        to_proto_with_vectors(req.with_vector),
        nothing,
        req.limit  !== nothing ? UInt64(req.limit) : UInt64(3),
        req.group_size !== nothing ? UInt64(req.group_size) : UInt64(1),
        req.group_by !== nothing ? req.group_by : "",
        nothing, nothing, UInt64(0), nothing,
    )
    resp = grpc_request(client.transport, Points_QueryGroups_Client, proto_req)
    QdrantResponse(_parse_grpc_groups(resp.result), "ok", resp.time)
end

function _parse_grpc_groups(::Nothing)::GroupsResult
    GroupsResult(GroupResult[])
end
function _parse_grpc_groups(gr::qdrant.GroupsResult)::GroupsResult
    groups = GroupResult[]
    for g in gr.groups
        gid = nothing
        if g.id !== nothing
            v = g.id.kind
            gid = v.name === :unsigned_value ? Int(v.value) :
                  v.name === :integer_value  ? Int(v.value) : v.value
        end
        hits = ScoredPoint[_grpc_to_scored(sp) for sp in g.hits]
        push!(groups, GroupResult(gid, hits))
    end
    GroupsResult(groups)
end
