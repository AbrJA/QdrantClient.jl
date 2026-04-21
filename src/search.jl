# ============================================================================
# Search API
# ============================================================================

"""
    search_points(client::Client, collection::String, request::SearchRequest)

Search for similar vectors in a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::SearchRequest`: Search configuration

# Returns
SearchResponse with scored points
"""
function search_points(
    client::Client,
    collection::String,
    request::SearchRequest
)
    body = QdrantClient._struct_to_dict(request)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/search",
        body
    )
    return _parse_response(response, SearchResponse)
end

"""
    search_batch(client::Client, collection::String, requests::Vector{SearchRequest})

Execute multiple search requests in a single batch.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `requests::Vector{SearchRequest}`: Search requests

# Returns
Vector of SearchResponse objects
"""
function search_batch(
    client::Client,
    collection::String,
    requests::Vector{SearchRequest}
)
    body = Dict(
        "searches" => [QdrantClient._struct_to_dict(r) for r in requests]
    )
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/search/batch",
        body
    )
    return _parse_response(response, Dict)
end

"""
    search_with_groups(client::Client, collection::String, request::Dict;
                       group_size::Int=1)

Search for vectors with grouping.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::Dict`: Search request
- `group_size::Int`: Size of each group

# Returns
Dict with grouped search results
"""
function search_with_groups(
    client::Client,
    collection::String,
    request::Dict;
    group_size::Int=1
)
    request_with_group = merge(request, Dict("group_size" => group_size))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/search/groups",
        request_with_group
    )
    return _parse_response(response, Dict)
end

"""
    recommend_points(client::Client, collection::String, request::RecommendRequest)

Get recommendations based on positive and negative point examples.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::RecommendRequest`: Recommendation configuration

# Returns
RecommendResponse with recommended points
"""
function recommend_points(
    client::Client,
    collection::String,
    request::RecommendRequest
)
    body = QdrantClient._struct_to_dict(request)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/recommend",
        body
    )
    return _parse_response(response, RecommendResponse)
end

"""
    recommend_batch(client::Client, collection::String, requests::Vector{RecommendRequest})

Execute multiple recommendation requests in a single batch.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `requests::Vector{RecommendRequest}`: Recommendation requests

# Returns
Vector of RecommendResponse objects
"""
function recommend_batch(
    client::Client,
    collection::String,
    requests::Vector{RecommendRequest}
)
    body = Dict(
        "searches" => [QdrantClient._struct_to_dict(r) for r in requests]
    )
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/recommend/batch",
        body
    )
    return _parse_response(response, Dict)
end

"""
    recommend_with_groups(client::Client, collection::String, request::Dict;
                          group_size::Int=1)

Get recommendations with grouping.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::Dict`: Recommendation request
- `group_size::Int`: Size of each group

# Returns
Dict with grouped recommendation results
"""
function recommend_with_groups(
    client::Client,
    collection::String,
    request::Dict;
    group_size::Int=1
)
    request_with_group = merge(request, Dict("group_size" => group_size))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/recommend/groups",
        request_with_group
    )
    return _parse_response(response, Dict)
end

"""
    query_points(client::Client, collection::String, request::QueryRequest)

Execute an advanced query on points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::QueryRequest`: Query configuration

# Returns
QueryResponse with query results
"""
function query_points(
    client::Client,
    collection::String,
    request::QueryRequest
)
    body = QdrantClient._struct_to_dict(request)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/query",
        body
    )
    return _parse_response(response, QueryResponse)
end

"""
    query_batch(client::Client, collection::String, requests::Vector{QueryRequest})

Execute multiple query requests in a single batch.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `requests::Vector{QueryRequest}`: Query requests

# Returns
Vector of QueryResponse objects
"""
function query_batch(
    client::Client,
    collection::String,
    requests::Vector{QueryRequest}
)
    body = Dict(
        "searches" => [QdrantClient._struct_to_dict(r) for r in requests]
    )
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/query/batch",
        body
    )
    return _parse_response(response, Dict)
end

"""
    query_with_groups(client::Client, collection::String, request::Dict;
                      group_size::Int=1)

Execute a query with grouping.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `request::Dict`: Query request
- `group_size::Int`: Size of each group

# Returns
Dict with grouped query results
"""
function query_with_groups(
    client::Client,
    collection::String,
    request::Dict;
    group_size::Int=1
)
    request_with_group = merge(request, Dict("group_size" => group_size))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/query/groups",
        request_with_group
    )
    return _parse_response(response, Dict)
end
