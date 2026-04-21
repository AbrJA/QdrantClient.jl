# ============================================================================
# Search / Recommend / Query API
# ============================================================================

search_path(collection::AbstractString) = "/collections/$collection/points"

# ── Search ───────────────────────────────────────────────────────────────

"""
    search_points(client, collection, request::SearchRequest)
    search_points(client, collection; vector, limit, kwargs...)

Search for nearest neighbors.

# Examples
```julia
search_points(client, "my_col", SearchRequest(vector=Float32[1,0,0,0], limit=5))
search_points(client, "my_col"; vector=Float32[1,0,0,0], limit=5, with_payload=true)
```
"""
function search_points(c::QdrantConnection, collection::AbstractString, req::SearchRequest)
    execute(HTTP.post, c, search_path(collection) * "/search", req)
end
search_points(collection::AbstractString, req::SearchRequest) =
    search_points(get_client(), collection, req)
search_points(c::QdrantConnection, collection::AbstractString; kwargs...) =
    search_points(c, collection, SearchRequest(; kwargs...))
search_points(collection::AbstractString; kwargs...) =
    search_points(get_client(), collection; kwargs...)

"""
    search_batch(client, collection, requests::AbstractVector{SearchRequest})

Execute multiple searches in one call.
"""
function search_batch(c::QdrantConnection, collection::AbstractString,
                      requests::AbstractVector{SearchRequest})
    body = Dict{String,Any}("searches" => collect(requests))
    execute(HTTP.post, c, search_path(collection) * "/search/batch", body)
end
search_batch(collection::AbstractString, requests::AbstractVector{SearchRequest}) =
    search_batch(get_client(), collection, requests)

"""
    search_groups(client, collection, request::AbstractDict; group_size=1)

Search with result grouping.
"""
function search_groups(c::QdrantConnection, collection::AbstractString,
                       req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    execute(HTTP.post, c, search_path(collection) * "/search/groups", body)
end
search_groups(collection::AbstractString, req::AbstractDict; kw...) =
    search_groups(get_client(), collection, req; kw...)

# ── Recommend ────────────────────────────────────────────────────────────

"""
    recommend_points(client, collection, request::RecommendRequest)
    recommend_points(client, collection; positive, limit, kwargs...)

Get recommendations from positive/negative examples.
"""
function recommend_points(c::QdrantConnection, collection::AbstractString, req::RecommendRequest)
    execute(HTTP.post, c, search_path(collection) * "/recommend", req)
end
recommend_points(collection::AbstractString, req::RecommendRequest) =
    recommend_points(get_client(), collection, req)
recommend_points(c::QdrantConnection, collection::AbstractString; kwargs...) =
    recommend_points(c, collection, RecommendRequest(; kwargs...))
recommend_points(collection::AbstractString; kwargs...) =
    recommend_points(get_client(), collection; kwargs...)

"""
    recommend_batch(client, collection, requests)

Execute multiple recommendations in one call.
"""
function recommend_batch(c::QdrantConnection, collection::AbstractString,
                         requests::AbstractVector{RecommendRequest})
    body = Dict{String,Any}("searches" => collect(requests))
    execute(HTTP.post, c, search_path(collection) * "/recommend/batch", body)
end
recommend_batch(collection::AbstractString, requests::AbstractVector{RecommendRequest}) =
    recommend_batch(get_client(), collection, requests)

"""
    recommend_groups(client, collection, request; group_size=1)

Recommendations with grouping.
"""
function recommend_groups(c::QdrantConnection, collection::AbstractString,
                          req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    execute(HTTP.post, c, search_path(collection) * "/recommend/groups", body)
end
recommend_groups(collection::AbstractString, req::AbstractDict; kw...) =
    recommend_groups(get_client(), collection, req; kw...)

# ── Query ────────────────────────────────────────────────────────────────

"""
    query_points(client, collection, request::QueryRequest)
    query_points(client, collection; query, limit, kwargs...)

Advanced query interface (Qdrant universal query API).
"""
function query_points(c::QdrantConnection, collection::AbstractString, req::QueryRequest)
    execute(HTTP.post, c, search_path(collection) * "/query", req)
end
query_points(collection::AbstractString, req::QueryRequest) =
    query_points(get_client(), collection, req)
query_points(c::QdrantConnection, collection::AbstractString; kwargs...) =
    query_points(c, collection, QueryRequest(; kwargs...))
query_points(collection::AbstractString; kwargs...) =
    query_points(get_client(), collection; kwargs...)

"""
    query_batch(client, collection, requests)

Execute multiple queries in one call.
"""
function query_batch(c::QdrantConnection, collection::AbstractString,
                     requests::AbstractVector{QueryRequest})
    body = Dict{String,Any}("searches" => collect(requests))
    execute(HTTP.post, c, search_path(collection) * "/query/batch", body)
end
query_batch(collection::AbstractString, requests::AbstractVector{QueryRequest}) =
    query_batch(get_client(), collection, requests)

"""
    query_groups(client, collection, request; group_size=1)

Query with grouping.
"""
function query_groups(c::QdrantConnection, collection::AbstractString,
                      req::AbstractDict; group_size::Int=1)
    body = merge(Dict{String,Any}(req), Dict{String,Any}("group_size" => group_size))
    execute(HTTP.post, c, search_path(collection) * "/query/groups", body)
end
query_groups(collection::AbstractString, req::AbstractDict; kw...) =
    query_groups(get_client(), collection, req; kw...)
