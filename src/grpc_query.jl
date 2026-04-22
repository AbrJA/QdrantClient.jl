# ============================================================================
# gRPC Query API — dispatch on GRPCTransport
# ============================================================================

# ── Query Points ─────────────────────────────────────────────────────────

function query_points(c::QdrantConnection, collection::AbstractString,
                      req::QueryRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    query = _build_grpc_query(req.query)
    proto_req = qdrant.QueryPoints(
        collection,
        qdrant.PrefetchQuery[],
        query,
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
    resp = grpc_request(transport, Points_Query_Client, proto_req)
    QueryResponse(ScoredPoint[_grpc_to_scored(sp) for sp in resp.result])
end

function _build_grpc_query(q::Nothing)
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
function _build_grpc_query(q::AbstractDict)
    nothing  # Complex dict queries (recommend/discover) not yet mapped to gRPC proto
end

function _grpc_to_scored(sp::qdrant.ScoredPoint)
    payload = isempty(sp.payload) ? nothing : from_proto_payload(sp.payload)
    vector = from_proto_vectors(sp.vectors)
    ScoredPoint(
        from_proto_point_id(sp.id),
        Int(sp.version),
        Float64(sp.score),
        payload,
        vector,
    )
end

# ── Query Batch ──────────────────────────────────────────────────────────

function query_batch(c::QdrantConnection, collection::AbstractString,
                     requests::AbstractVector{QueryRequest}, ::Val{:grpc})
    transport = c.transport::GRPCTransport
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
    resp = grpc_request(transport, Points_QueryBatch_Client, proto_req)
    QueryResponse[QueryResponse(ScoredPoint[_grpc_to_scored(sp) for sp in batch.result])
                  for batch in resp.result]
end

# ── Query Groups ─────────────────────────────────────────────────────────

function query_groups(c::QdrantConnection, collection::AbstractString,
                      req::QueryRequest, ::Val{:grpc})
    transport = c.transport::GRPCTransport
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
        nothing,  # lookup_from
        req.limit !== nothing ? UInt64(req.limit) : UInt64(3),
        req.group_size !== nothing ? UInt64(req.group_size) : UInt64(1),
        req.group_by !== nothing ? req.group_by : "",
        nothing, nothing, UInt64(0), nothing,
    )
    resp = grpc_request(transport, Points_QueryGroups_Client, proto_req)
    _grpc_groups_response(resp.result)
end

function _grpc_groups_response(gr::Nothing)
    GroupsResponse(GroupResult[])
end
function _grpc_groups_response(gr::qdrant.GroupsResult)
    groups = GroupResult[]
    for g in gr.groups
        gid = nothing
        if g.id !== nothing
            v = g.id.kind
            gid = v.name === :unsigned_value ? Int(v.value) :
                  v.name === :integer_value ? Int(v.value) :
                  v.value
        end
        hits = ScoredPoint[_grpc_to_scored(sp) for sp in g.hits]
        push!(groups, GroupResult(gid, hits))
    end
    GroupsResponse(groups)
end
