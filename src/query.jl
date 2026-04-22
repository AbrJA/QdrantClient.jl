# ============================================================================
# Query API — modern unified search/recommend/discover interface
# Also: search matrix and facet endpoints
# ============================================================================

query_path(collection::AbstractString) = "/collections/$collection/points"

# ── Query Points ─────────────────────────────────────────────────────────

"""
    query_points(client, collection, request::QueryRequest) -> QueryResponse
    query_points(client, collection; query, limit, kwargs...) -> QueryResponse

Universal query API — replaces the deprecated `search_points`, `recommend_points`,
and `discover_points` endpoints.

# Examples
```julia
# Nearest-neighbor search
query_points(client, "demo", QueryRequest(query=Float32[1,0,0,0], limit=5))

# With kwargs
query_points(client, "demo"; query=Float32[1,0,0,0], limit=5, with_payload=true)

# Recommendation via query API
query_points(client, "demo",
    QueryRequest(query=Dict("recommend" => Dict("positive" => [1])), limit=5))
```
"""
function query_points(c::QdrantConnection, collection::AbstractString, req::QueryRequest)
    is_grpc(c) && return query_points(c, collection, req, Val(:grpc))
    parse_query(request(HTTP.post, c, query_path(collection) * "/query", req))
end
query_points(collection::AbstractString, req::QueryRequest) =
    query_points(get_client(), collection, req)
query_points(c::QdrantConnection, collection::AbstractString; kwargs...) =
    query_points(c, collection, QueryRequest(; kwargs...))
query_points(collection::AbstractString; kwargs...) =
    query_points(get_client(), collection; kwargs...)

"""
    query_batch(client, collection, requests) -> Vector{QueryResponse}

Execute multiple queries in one call.
"""
function query_batch(c::QdrantConnection, collection::AbstractString,
                     requests::AbstractVector{QueryRequest})
    is_grpc(c) && return query_batch(c, collection, requests, Val(:grpc))
    body = Dict{String,Any}("searches" => collect(requests))
    resp = request(HTTP.post, c, query_path(collection) * "/query/batch", body)
    r = parse_response(resp)
    r isa AbstractVector || return QueryResponse[]
    QueryResponse[QueryResponse(parse_scored_points(get(batch, "points", Any[]))) for batch in r]
end
query_batch(collection::AbstractString, requests::AbstractVector{QueryRequest}) =
    query_batch(get_client(), collection, requests)

"""
    query_groups(client, collection, request::QueryRequest) -> GroupsResponse

Query with result grouping. Set `group_by` and `group_size` in the QueryRequest.

# Examples
```julia
query_groups(client, "demo", QueryRequest(
    query=Float32[1,0,0,0], limit=10, group_by="category", group_size=3))
```
"""
function query_groups(c::QdrantConnection, collection::AbstractString, req::QueryRequest)
    is_grpc(c) && return query_groups(c, collection, req, Val(:grpc))
    parse_groups(request(HTTP.post, c, query_path(collection) * "/query/groups", req))
end
query_groups(collection::AbstractString, req::QueryRequest) =
    query_groups(get_client(), collection, req)

# ── Search Matrix ────────────────────────────────────────────────────────

"""
    search_matrix_pairs(client, collection; filter, sample, limit) -> SearchMatrixPairsResponse

Compute pairwise distance matrix in pair format.
"""
function search_matrix_pairs(c::QdrantConnection, collection::AbstractString;
                             filter::Optional{Filter}=nothing,
                             sample::Optional{Int}=nothing,
                             limit::Optional{Int}=nothing)
    body = Dict{String,Any}()
    filter !== nothing && (body["filter"] = filter)
    sample !== nothing && (body["sample"] = sample)
    limit !== nothing && (body["limit"] = limit)
    resp = request(HTTP.post, c, query_path(collection) * "/search/matrix/pairs", body)
    r = parse_response(resp)
    r isa AbstractDict || return SearchMatrixPairsResponse(Dict{String,Any}[])
    SearchMatrixPairsResponse(get(r, "pairs", Dict{String,Any}[]))
end
search_matrix_pairs(collection::AbstractString; kw...) =
    search_matrix_pairs(get_client(), collection; kw...)

"""
    search_matrix_offsets(client, collection; filter, sample, limit) -> SearchMatrixOffsetsResponse

Compute pairwise distance matrix in offset format.
"""
function search_matrix_offsets(c::QdrantConnection, collection::AbstractString;
                               filter::Optional{Filter}=nothing,
                               sample::Optional{Int}=nothing,
                               limit::Optional{Int}=nothing)
    body = Dict{String,Any}()
    filter !== nothing && (body["filter"] = filter)
    sample !== nothing && (body["sample"] = sample)
    limit !== nothing && (body["limit"] = limit)
    resp = request(HTTP.post, c, query_path(collection) * "/search/matrix/offsets", body)
    r = parse_response(resp)
    r isa AbstractDict || return SearchMatrixOffsetsResponse(Int[], Int[], Float64[], PointId[])
    SearchMatrixOffsetsResponse(
        Int.(get(r, "offsets_row", Int[])),
        Int.(get(r, "offsets_col", Int[])),
        Float64.(get(r, "scores", Float64[])),
        PointId[_dict_to_point_id(x) for x in get(r, "ids", Any[])],
    )
end
search_matrix_offsets(collection::AbstractString; kw...) =
    search_matrix_offsets(get_client(), collection; kw...)

# ── Facet ────────────────────────────────────────────────────────────────

"""
    facet(client, collection, key; filter, limit, exact) -> FacetResponse

Get value counts for a payload field (faceted search).

# Examples
```julia
facet(client, "demo", "color")
facet(client, "demo", "category"; limit=20)
```
"""
function facet(c::QdrantConnection, collection::AbstractString, key::AbstractString;
               filter::Optional{Filter}=nothing,
               limit::Optional{Int}=nothing,
               exact::Optional{Bool}=nothing)
    body = Dict{String,Any}("key" => key)
    filter !== nothing && (body["filter"] = filter)
    limit !== nothing && (body["limit"] = limit)
    exact !== nothing && (body["exact"] = exact)
    parse_facet(request(HTTP.post, c, "/collections/$collection/facet", body))
end
facet(collection::AbstractString, key::AbstractString; kw...) =
    facet(get_client(), collection, key; kw...)
