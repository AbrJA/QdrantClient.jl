# ============================================================================
# Discovery API
# ============================================================================

"""
    discover_points(client::Client, collection::String, request::DiscoverRequest)

Discover points similar to a target point, with optional context.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::DiscoverRequest`: Discovery configuration

# Returns
DiscoverResponse with discovered points
"""
function discover_points(
    client::Client,
    collection::String,
    request::DiscoverRequest
)
    body = QdrantClient._struct_to_dict(request)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/discover",
        body
    )
    return _parse_response(response, DiscoverResponse)
end

"""
    discover_batch(client::Client, collection::String, requests::Vector{DiscoverRequest})

Execute multiple discovery requests in a single batch.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `requests::Vector{DiscoverRequest}`: Discovery requests

# Returns
Vector of DiscoverResponse objects
"""
function discover_batch(
    client::Client,
    collection::String,
    requests::Vector{DiscoverRequest}
)
    body = Dict(
        "searches" => [QdrantClient._struct_to_dict(r) for r in requests]
    )
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/discover/batch",
        body
    )
    return _parse_response(response, Dict)
end
