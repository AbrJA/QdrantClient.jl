# ============================================================================
# Points API — CRUD, Payload, Vectors, Scroll, Count, Batch, Index
# ============================================================================

points_path(collection::AbstractString) = "/collections/$collection/points"

# ── Selector dispatch ────────────────────────────────────────────────────

point_selector(ids::AbstractVector{<:PointId}) = Dict{String,Any}("points" => collect(ids))
point_selector(f::Filter) = Dict{String,Any}("filter" => f)
point_selector(id::PointId) = point_selector([id])

wait_query(wait::Bool) = Dict("wait" => wait)

# ============================================================================
# CRUD
# ============================================================================

"""
    upsert_points(client, collection, points; wait=true, ordering="weak") -> UpdateResponse

Insert or update points.
"""
function upsert_points(c::QdrantConnection, collection::AbstractString,
                       points::AbstractVector{<:Point};
                       wait::Bool=true, ordering::AbstractString="weak")
    is_grpc(c) && return upsert_points(c, collection, points, Val(:grpc); wait, ordering)
    body = Dict{String,Any}("points" => points, "ordering" => ordering)
    parse_update(request(HTTP.put, c, points_path(collection), body; query=wait_query(wait)))
end
upsert_points(collection::AbstractString, points::AbstractVector{<:Point}; kw...) =
    upsert_points(get_client(), collection, points; kw...)

"""
    delete_points(client, collection, selector; wait=true) -> UpdateResponse

Delete points by IDs or filter.

# Dispatch
- `selector::AbstractVector{<:PointId}` — delete by ID list
- `selector::PointId` — delete single point
- `selector::Filter` — delete by filter
"""
function delete_points(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    is_grpc(c) && return delete_points(c, collection, selector, Val(:grpc); wait)
    parse_update(request(HTTP.post, c, points_path(collection) * "/delete",
            point_selector(selector); query=wait_query(wait)))
end
delete_points(collection::AbstractString, selector; kw...) =
    delete_points(get_client(), collection, selector; kw...)

"""
    get_points(client, collection, ids; with_vectors=false, with_payload=true) -> Vector{Record}

Retrieve multiple points by IDs.
"""
function get_points(c::QdrantConnection, collection::AbstractString,
                    ids::AbstractVector{<:PointId};
                    with_vectors::Bool=false, with_payload::Bool=true)
    is_grpc(c) && return get_points(c, collection, ids, Val(:grpc); with_vectors, with_payload)
    body = Dict{String,Any}(
        "ids" => collect(ids),
        "with_vectors" => with_vectors,
        "with_payload" => with_payload,
    )
    parse_records(request(HTTP.post, c, points_path(collection), body))
end
get_points(c::QdrantConnection, collection::AbstractString, id::PointId; kw...) =
    get_points(c, collection, [id]; kw...)
get_points(collection::AbstractString, ids; kw...) =
    get_points(get_client(), collection, ids; kw...)

"""
    get_point(client, collection, id) -> Record

Retrieve a single point by ID (REST-only — uses GET endpoint).
"""
function get_point(c::QdrantConnection, collection::AbstractString, id::PointId)
    resp = request(HTTP.get, c, points_path(collection) * "/$id")
    r = parse_response(resp)
    r isa AbstractDict || error("Unexpected response for get_point")
    _dict_to_record(r)
end
get_point(collection::AbstractString, id::PointId) = get_point(get_client(), collection, id)

# ============================================================================
# Payload operations
# ============================================================================

"""
    set_payload(client, collection, payload, selector; wait=true) -> UpdateResponse

Set payload fields on selected points.
"""
function set_payload(c::QdrantConnection, collection::AbstractString, payload::AbstractDict,
                     selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                     wait::Bool=true)
    is_grpc(c) && return set_payload(c, collection, payload, selector, Val(:grpc); wait)
    body = merge(Dict{String,Any}("payload" => payload), point_selector(selector))
    parse_update(request(HTTP.post, c, points_path(collection) * "/payload", body; query=wait_query(wait)))
end
set_payload(collection::AbstractString, payload::AbstractDict, selector; kw...) =
    set_payload(get_client(), collection, payload, selector; kw...)

"""
    overwrite_payload(client, collection, payload, selector; wait=true) -> UpdateResponse

Replace the entire payload on selected points (removes unlisted keys).
"""
function overwrite_payload(c::QdrantConnection, collection::AbstractString, payload::AbstractDict,
                           selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                           wait::Bool=true)
    is_grpc(c) && return overwrite_payload(c, collection, payload, selector, Val(:grpc); wait)
    body = merge(Dict{String,Any}("payload" => payload), point_selector(selector))
    parse_update(request(HTTP.put, c, points_path(collection) * "/payload", body; query=wait_query(wait)))
end
overwrite_payload(collection::AbstractString, payload::AbstractDict, selector; kw...) =
    overwrite_payload(get_client(), collection, payload, selector; kw...)

"""
    delete_payload(client, collection, keys, selector; wait=true) -> UpdateResponse

Delete payload keys from selected points.
"""
function delete_payload(c::QdrantConnection, collection::AbstractString,
                        keys::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    is_grpc(c) && return delete_payload(c, collection, keys, selector, Val(:grpc); wait)
    body = merge(Dict{String,Any}("keys" => collect(keys)), point_selector(selector))
    parse_update(request(HTTP.post, c, points_path(collection) * "/payload/delete", body;
            query=wait_query(wait)))
end
delete_payload(collection::AbstractString, keys::AbstractVector{<:AbstractString}, selector; kw...) =
    delete_payload(get_client(), collection, keys, selector; kw...)

"""
    clear_payload(client, collection, selector; wait=true) -> UpdateResponse

Remove all payload from selected points.
"""
function clear_payload(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    is_grpc(c) && return clear_payload(c, collection, selector, Val(:grpc); wait)
    parse_update(request(HTTP.post, c, points_path(collection) * "/payload/clear",
            point_selector(selector); query=wait_query(wait)))
end
clear_payload(collection::AbstractString, selector; kw...) =
    clear_payload(get_client(), collection, selector; kw...)

# ============================================================================
# Vector operations
# ============================================================================

"""
    update_vectors(client, collection, points; wait=true) -> UpdateResponse

Update vectors for existing points.
"""
function update_vectors(c::QdrantConnection, collection::AbstractString,
                        points::AbstractVector; wait::Bool=true)
    is_grpc(c) && return update_vectors(c, collection, points, Val(:grpc); wait)
    body = Dict{String,Any}("points" => collect(points))
    parse_update(request(HTTP.put, c, points_path(collection) * "/vectors", body; query=wait_query(wait)))
end
update_vectors(collection::AbstractString, points::AbstractVector; kw...) =
    update_vectors(get_client(), collection, points; kw...)

"""
    delete_vectors(client, collection, vector_names, selector; wait=true) -> UpdateResponse

Delete named vector fields from selected points.
"""
function delete_vectors(c::QdrantConnection, collection::AbstractString,
                        names::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    is_grpc(c) && return delete_vectors(c, collection, names, selector, Val(:grpc); wait)
    body = merge(Dict{String,Any}("vector" => collect(names)), point_selector(selector))
    parse_update(request(HTTP.post, c, points_path(collection) * "/vectors/delete", body;
            query=wait_query(wait)))
end
delete_vectors(collection::AbstractString, names::AbstractVector{<:AbstractString}, selector; kw...) =
    delete_vectors(get_client(), collection, names, selector; kw...)

# ============================================================================
# Scroll & Count
# ============================================================================

"""
    scroll_points(client, collection; filter, limit, offset, with_vectors, with_payload) -> ScrollResponse

Scroll through points with optional filtering.
"""
function scroll_points(c::QdrantConnection, collection::AbstractString;
                       filter::Optional{Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    is_grpc(c) && return scroll_points(c, collection, Val(:grpc); filter, limit, offset, with_vectors, with_payload)
    body = Dict{String,Any}(
        "limit" => limit,
        "with_vectors" => with_vectors,
        "with_payload" => with_payload,
    )
    filter !== nothing && (body["filter"] = filter)
    offset !== nothing && (body["offset"] = offset)
    parse_scroll(request(HTTP.post, c, points_path(collection) * "/scroll", body))
end
scroll_points(collection::AbstractString; kw...) =
    scroll_points(get_client(), collection; kw...)

"""
    count_points(client, collection; filter, exact) -> CountResponse

Count points in a collection.
"""
function count_points(c::QdrantConnection, collection::AbstractString;
                      filter::Optional{Filter}=nothing, exact::Bool=false)
    is_grpc(c) && return count_points(c, collection, Val(:grpc); filter, exact)
    body = Dict{String,Any}("exact" => exact)
    filter !== nothing && (body["filter"] = filter)
    parse_count(request(HTTP.post, c, points_path(collection) * "/count", body))
end
count_points(collection::AbstractString; kw...) =
    count_points(get_client(), collection; kw...)

# ============================================================================
# Batch
# ============================================================================

"""
    batch_points(client, collection, operations; wait=true) -> Vector{UpdateResponse}

Execute multiple point operations in a single batch call.
"""
function batch_points(c::QdrantConnection, collection::AbstractString,
                      operations::AbstractVector; wait::Bool=true)
    body = Dict{String,Any}("operations" => operations)
    resp = request(HTTP.post, c, points_path(collection) * "/batch", body; query=wait_query(wait))
    r = parse_response(resp)
    r isa AbstractVector || return UpdateResponse[]
    UpdateResponse[UpdateResponse(
        get(x, "operation_id", 0),
        get(x, "status", "completed"),
    ) for x in r]
end
batch_points(collection::AbstractString, operations::AbstractVector; kw...) =
    batch_points(get_client(), collection, operations; kw...)

# ============================================================================
# Payload Index
# ============================================================================

"""
    create_payload_index(client, collection, field_name; field_schema, wait=true) -> UpdateResponse

Create an index on a payload field.
"""
function create_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString;
                              field_schema::Union{String, AbstractQdrantType, AbstractDict, Nothing}=nothing,
                              wait::Bool=true)
    is_grpc(c) && return create_payload_index(c, collection, field_name, Val(:grpc); field_schema, wait)
    body = Dict{String,Any}("field_name" => field_name)
    field_schema !== nothing && (body["field_schema"] = field_schema)
    parse_update(request(HTTP.put, c, collection_path(collection) * "/index", body;
            query=wait_query(wait)))
end
create_payload_index(collection::AbstractString, field_name::AbstractString; kw...) =
    create_payload_index(get_client(), collection, field_name; kw...)

"""
    delete_payload_index(client, collection, field_name; wait=true) -> UpdateResponse

Delete an index on a payload field.
"""
function delete_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString; wait::Bool=true)
    is_grpc(c) && return delete_payload_index(c, collection, field_name, Val(:grpc); wait)
    parse_update(request(HTTP.delete, c, collection_path(collection) * "/index/$field_name";
            query=wait_query(wait)))
end
delete_payload_index(collection::AbstractString, field_name::AbstractString; kw...) =
    delete_payload_index(get_client(), collection, field_name; kw...)
# ============================================================================
