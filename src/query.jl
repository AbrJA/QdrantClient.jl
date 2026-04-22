# ============================================================================
# Query API — HTTP transport
# ============================================================================

_query_path(collection::AbstractString) = "/collections/$collection/points"

# ── Query Points ─────────────────────────────────────────────────────────

"""
    query_points(conn, collection, request) -> QdrantResponse{QueryResult}
    query_points(conn, collection; query, limit, kwargs...) -> QdrantResponse{QueryResult}

Universal query API — replaces the deprecated search/recommend/discover endpoints.

# Examples
```julia
query_points(conn, "demo", QueryRequest(query=Float32[1,0,0,0], limit=5))
query_points(conn, "demo"; query=Float32[1,0,0,0], limit=5, with_payload=true)
```
"""
function query_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                      req::QueryRequest)
    parse_query(http_request(HTTP.post, conn, _query_path(collection) * "/query", req))
end
query_points(collection::AbstractString, req::QueryRequest) =
    query_points(get_client(), collection, req)
query_points(conn::QdrantConnection, collection::AbstractString; kwargs...) =
    query_points(conn, collection, QueryRequest(; kwargs...))
query_points(collection::AbstractString; kwargs...) =
    query_points(get_client(), collection; kwargs...)

# ── Query Batch ──────────────────────────────────────────────────────────

"""
    query_batch(conn, collection, requests) -> QdrantResponse{Vector{QueryResult}}

Execute multiple queries in one call.
"""
function query_batch(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                     requests::AbstractVector{QueryRequest})
    body = Dict{String,Any}("searches" => collect(requests))
    resp = http_request(HTTP.post, conn, _query_path(collection) * "/query/batch", body)
    raw, status, time = _unwrap(resp)
    results = if raw isa AbstractVector
        QueryResult[QueryResult(ScoredPoint[_to_scored(p) for p in get(batch, "points", Any[])])
                    for batch in raw]
    else
        QueryResult[]
    end
    QdrantResponse(results, status, time)
end
query_batch(collection::AbstractString, requests::AbstractVector{QueryRequest}) =
    query_batch(get_client(), collection, requests)

# ── Query Groups ─────────────────────────────────────────────────────────

"""
    query_groups(conn, collection, request) -> QdrantResponse{GroupsResult}

Query with result grouping.

# Examples
```julia
query_groups(conn, "demo", QueryRequest(
    query=Float32[1,0,0,0], limit=10, group_by="category", group_size=3))
```
"""
function query_groups(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                      req::QueryRequest)
    parse_groups(http_request(HTTP.post, conn, _query_path(collection) * "/query/groups", req))
end
query_groups(collection::AbstractString, req::QueryRequest) =
    query_groups(get_client(), collection, req)

# ── Search Matrix ────────────────────────────────────────────────────────

"""
    search_matrix_pairs(conn, collection; filter, sample, limit) -> QdrantResponse{SearchMatrixPairsResponse}

Compute pairwise distance matrix in pair format.
"""
function search_matrix_pairs(conn::QdrantConnection{HTTPTransport}, collection::AbstractString;
                             filter::Optional{Filter}=nothing,
                             sample::Optional{Int}=nothing,
                             limit::Optional{Int}=nothing)
    body = Dict{String,Any}()
    filter !== nothing && (body["filter"] = filter)
    sample !== nothing && (body["sample"] = sample)
    limit  !== nothing && (body["limit"] = limit)
    resp = http_request(HTTP.post, conn, _query_path(collection) * "/search/matrix/pairs", body)
    raw, status, time = _unwrap(resp)
    pairs = raw isa AbstractDict ? get(raw, "pairs", Dict{String,Any}[]) : Dict{String,Any}[]
    QdrantResponse(SearchMatrixPairsResponse(pairs), status, time)
end
search_matrix_pairs(collection::AbstractString; kw...) =
    search_matrix_pairs(get_client(), collection; kw...)

"""
    search_matrix_offsets(conn, collection; filter, sample, limit) -> QdrantResponse{SearchMatrixOffsetsResponse}

Compute pairwise distance matrix in offset format.
"""
function search_matrix_offsets(conn::QdrantConnection{HTTPTransport}, collection::AbstractString;
                               filter::Optional{Filter}=nothing,
                               sample::Optional{Int}=nothing,
                               limit::Optional{Int}=nothing)
    body = Dict{String,Any}()
    filter !== nothing && (body["filter"] = filter)
    sample !== nothing && (body["sample"] = sample)
    limit  !== nothing && (body["limit"] = limit)
    resp = http_request(HTTP.post, conn, _query_path(collection) * "/search/matrix/offsets", body)
    raw, status, time = _unwrap(resp)
    result = if raw isa AbstractDict
        SearchMatrixOffsetsResponse(
            Int.(get(raw, "offsets_row", Int[])),
            Int.(get(raw, "offsets_col", Int[])),
            Float64.(get(raw, "scores", Float64[])),
            PointId[_to_point_id(x) for x in get(raw, "ids", Any[])],
        )
    else
        SearchMatrixOffsetsResponse(Int[], Int[], Float64[], PointId[])
    end
    QdrantResponse(result, status, time)
end
search_matrix_offsets(collection::AbstractString; kw...) =
    search_matrix_offsets(get_client(), collection; kw...)

# ── Facet ────────────────────────────────────────────────────────────────

"""
    facet(conn, collection, key; filter, limit, exact) -> QdrantResponse{FacetResult}

Get value counts for a payload field (faceted search).
"""
function facet(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
               key::AbstractString;
               filter::Optional{Filter}=nothing,
               limit::Optional{Int}=nothing,
               exact::Optional{Bool}=nothing)
    body = Dict{String,Any}("key" => key)
    filter !== nothing && (body["filter"] = filter)
    limit  !== nothing && (body["limit"] = limit)
    exact  !== nothing && (body["exact"] = exact)
    parse_facet(http_request(HTTP.post, conn, "/collections/$collection/facet", body))
end
facet(collection::AbstractString, key::AbstractString; kw...) =
    facet(get_client(), collection, key; kw...)
