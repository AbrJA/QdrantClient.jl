# ============================================================================
# Points API — HTTP transport
# ============================================================================

_points_path(collection::AbstractString) = "/collections/$collection/points"

_point_selector(ids::AbstractVector{<:PointId}) = Dict{String,Any}("points" => collect(ids))
_point_selector(f::Filter) = Dict{String,Any}("filter" => f)
_point_selector(id::PointId) = _point_selector([id])

_wait_query(wait::Bool) = Dict("wait" => wait)

# ── Upsert ───────────────────────────────────────────────────────────────

"""
    upsert_points(conn, collection, points; wait=true, ordering="weak") -> QdrantResponse{UpdateResult}

Insert or update points.
"""
function upsert_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                       points::AbstractVector{<:Point};
                       wait::Bool=true, ordering::AbstractString="weak")
    body = Dict{String,Any}("points" => points, "ordering" => ordering)
    parse_update(http_request(HTTP.put, conn, _points_path(collection), body;
                              query=_wait_query(wait)))
end
upsert_points(collection::AbstractString, points::AbstractVector{<:Point}; kw...) =
    upsert_points(get_client(), collection, points; kw...)

# ── Delete ───────────────────────────────────────────────────────────────

"""
    delete_points(conn, collection, selector; wait=true) -> QdrantResponse{UpdateResult}

Delete points by IDs or filter.
"""
function delete_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    parse_update(http_request(HTTP.post, conn, _points_path(collection) * "/delete",
                              _point_selector(selector); query=_wait_query(wait)))
end
delete_points(collection::AbstractString, selector; kw...) =
    delete_points(get_client(), collection, selector; kw...)

# ── Get ──────────────────────────────────────────────────────────────────

"""
    get_points(conn, collection, ids; with_vectors=false, with_payload=true) -> QdrantResponse{Vector{Record}}

Retrieve multiple points by IDs.
"""
function get_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                    ids::AbstractVector{<:PointId};
                    with_vectors::Bool=false, with_payload::Bool=true)
    body = Dict{String,Any}(
        "ids"          => collect(ids),
        "with_vectors" => with_vectors,
        "with_payload" => with_payload,
    )
    parse_records(http_request(HTTP.post, conn, _points_path(collection), body))
end
get_points(conn::QdrantConnection, collection::AbstractString, id::PointId; kw...) =
    get_points(conn, collection, [id]; kw...)
get_points(collection::AbstractString, ids; kw...) =
    get_points(get_client(), collection, ids; kw...)

"""
    get_point(conn, collection, id) -> QdrantResponse{Record}

Retrieve a single point by ID (HTTP only — uses GET endpoint).
"""
function get_point(conn::QdrantConnection{HTTPTransport}, collection::AbstractString, id::PointId)
    resp = http_request(HTTP.get, conn, _points_path(collection) * "/$id")
    raw, status, time = _unwrap(resp)
    raw isa AbstractDict || error("Unexpected response for get_point")
    QdrantResponse(_to_record(raw), status, time)
end
get_point(collection::AbstractString, id::PointId) = get_point(get_client(), collection, id)

# ============================================================================
# Payload operations
# ============================================================================

"""
    set_payload(conn, collection, payload, selector; wait=true) -> QdrantResponse{UpdateResult}

Set payload fields on selected points.
"""
function set_payload(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                     payload::AbstractDict,
                     selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                     wait::Bool=true)
    body = merge(Dict{String,Any}("payload" => payload), _point_selector(selector))
    parse_update(http_request(HTTP.post, conn, _points_path(collection) * "/payload", body;
                              query=_wait_query(wait)))
end
set_payload(collection::AbstractString, payload::AbstractDict, selector; kw...) =
    set_payload(get_client(), collection, payload, selector; kw...)

"""
    overwrite_payload(conn, collection, payload, selector; wait=true) -> QdrantResponse{UpdateResult}

Replace the entire payload on selected points (removes unlisted keys).
"""
function overwrite_payload(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                           payload::AbstractDict,
                           selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                           wait::Bool=true)
    body = merge(Dict{String,Any}("payload" => payload), _point_selector(selector))
    parse_update(http_request(HTTP.put, conn, _points_path(collection) * "/payload", body;
                              query=_wait_query(wait)))
end
overwrite_payload(collection::AbstractString, payload::AbstractDict, selector; kw...) =
    overwrite_payload(get_client(), collection, payload, selector; kw...)

"""
    delete_payload(conn, collection, keys, selector; wait=true) -> QdrantResponse{UpdateResult}

Delete payload keys from selected points.
"""
function delete_payload(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                        keys::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    body = merge(Dict{String,Any}("keys" => collect(keys)), _point_selector(selector))
    parse_update(http_request(HTTP.post, conn, _points_path(collection) * "/payload/delete",
                              body; query=_wait_query(wait)))
end
delete_payload(collection::AbstractString, keys::AbstractVector{<:AbstractString}, selector; kw...) =
    delete_payload(get_client(), collection, keys, selector; kw...)

"""
    clear_payload(conn, collection, selector; wait=true) -> QdrantResponse{UpdateResult}

Remove all payload from selected points.
"""
function clear_payload(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    parse_update(http_request(HTTP.post, conn, _points_path(collection) * "/payload/clear",
                              _point_selector(selector); query=_wait_query(wait)))
end
clear_payload(collection::AbstractString, selector; kw...) =
    clear_payload(get_client(), collection, selector; kw...)

# ============================================================================
# Vector operations
# ============================================================================

"""
    update_vectors(conn, collection, points; wait=true) -> QdrantResponse{UpdateResult}

Update vectors for existing points.
"""
function update_vectors(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                        points::AbstractVector; wait::Bool=true)
    body = Dict{String,Any}("points" => collect(points))
    parse_update(http_request(HTTP.put, conn, _points_path(collection) * "/vectors", body;
                              query=_wait_query(wait)))
end
update_vectors(collection::AbstractString, points::AbstractVector; kw...) =
    update_vectors(get_client(), collection, points; kw...)

"""
    delete_vectors(conn, collection, vector_names, selector; wait=true) -> QdrantResponse{UpdateResult}

Delete named vector fields from selected points.
"""
function delete_vectors(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                        names::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    body = merge(Dict{String,Any}("vector" => collect(names)), _point_selector(selector))
    parse_update(http_request(HTTP.post, conn, _points_path(collection) * "/vectors/delete",
                              body; query=_wait_query(wait)))
end
delete_vectors(collection::AbstractString, names::AbstractVector{<:AbstractString}, selector; kw...) =
    delete_vectors(get_client(), collection, names, selector; kw...)

# ============================================================================
# Scroll & Count
# ============================================================================

"""
    scroll_points(conn, collection; filter, limit, offset, with_vectors, with_payload) -> QdrantResponse{ScrollResult}

Scroll through points with optional filtering.
"""
function scroll_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString;
                       filter::Optional{Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    body = Dict{String,Any}(
        "limit"        => limit,
        "with_vectors" => with_vectors,
        "with_payload" => with_payload,
    )
    filter !== nothing && (body["filter"] = filter)
    offset !== nothing && (body["offset"] = offset)
    parse_scroll(http_request(HTTP.post, conn, _points_path(collection) * "/scroll", body))
end
scroll_points(collection::AbstractString; kw...) =
    scroll_points(get_client(), collection; kw...)

"""
    count_points(conn, collection; filter, exact) -> QdrantResponse{CountResult}

Count points in a collection.
"""
function count_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString;
                      filter::Optional{Filter}=nothing, exact::Bool=false)
    body = Dict{String,Any}("exact" => exact)
    filter !== nothing && (body["filter"] = filter)
    parse_count(http_request(HTTP.post, conn, _points_path(collection) * "/count", body))
end
count_points(collection::AbstractString; kw...) =
    count_points(get_client(), collection; kw...)

# ============================================================================
# Batch
# ============================================================================

"""
    batch_points(conn, collection, operations; wait=true) -> QdrantResponse{Vector{UpdateResult}}

Execute multiple point operations in a single batch call.
"""
function batch_points(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                      operations::AbstractVector; wait::Bool=true)
    body = Dict{String,Any}("operations" => operations)
    resp = http_request(HTTP.post, conn, _points_path(collection) * "/batch", body;
                        query=_wait_query(wait))
    raw, status, time = _unwrap(resp)
    results = raw isa AbstractVector ?
        UpdateResult[_to_update_result(x) for x in raw] : UpdateResult[]
    QdrantResponse(results, status, time)
end
batch_points(collection::AbstractString, operations::AbstractVector; kw...) =
    batch_points(get_client(), collection, operations; kw...)

# ============================================================================
# Payload Index
# ============================================================================

"""
    create_payload_index(conn, collection, field_name; field_schema, wait=true) -> QdrantResponse{UpdateResult}

Create an index on a payload field.
"""
function create_payload_index(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                              field_name::AbstractString;
                              field_schema::Union{String, AbstractQdrantType, AbstractDict, Nothing}=nothing,
                              wait::Bool=true)
    body = Dict{String,Any}("field_name" => field_name)
    field_schema !== nothing && (body["field_schema"] = field_schema)
    parse_update(http_request(HTTP.put, conn, _collection_path(collection) * "/index", body;
                              query=_wait_query(wait)))
end
create_payload_index(collection::AbstractString, field_name::AbstractString; kw...) =
    create_payload_index(get_client(), collection, field_name; kw...)

"""
    delete_payload_index(conn, collection, field_name; wait=true) -> QdrantResponse{UpdateResult}

Delete an index on a payload field.
"""
function delete_payload_index(conn::QdrantConnection{HTTPTransport}, collection::AbstractString,
                              field_name::AbstractString; wait::Bool=true)
    parse_update(http_request(HTTP.delete, conn, _collection_path(collection) * "/index/$field_name";
                              query=_wait_query(wait)))
end
delete_payload_index(collection::AbstractString, field_name::AbstractString; kw...) =
    delete_payload_index(get_client(), collection, field_name; kw...)
