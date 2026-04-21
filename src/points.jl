# ============================================================================
# Points API
# ============================================================================

_selector_body(points::AbstractVector{<:PointId}) = Dict{String, Any}("points" => collect(points))
_selector_body(filter::Filter) = Dict{String, Any}("filter" => QdrantClient._struct_to_dict(filter))

_points_payload(ids::AbstractVector{<:PointId}; with_vectors::Bool=false, with_payload::Bool=true) = Dict{String, Any}(
    "ids" => collect(ids),
    "with_vectors" => with_vectors,
    "with_payload" => with_payload,
)

_wait_query(wait::Bool) = Dict("wait" => wait)

_point_results(points::AbstractVector) = points
_point_results(parsed::AbstractDict) = get(parsed, :points, Any[])

"""
    upsert_points(client::Client, collection::String, points::Vector{PointStruct};
                  wait::Bool=true, ordering::String="weak")

Upsert (insert or update) points to a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `points::Vector{PointStruct}`: Points to upsert
- `wait::Bool`: Whether to wait for the operation to complete
- `ordering::String`: Write ordering ("weak", "medium", "strong")

# Returns
Dict with operation status
"""
function upsert_points(
    client::Client,
    collection::String,
    points::Vector{PointStruct};
    wait::Bool=true,
    ordering::String="weak"
)
    body = Dict(
        "points" => [QdrantClient._struct_to_dict(p) for p in points],
        "ordering" => ordering
    )
    query = Dict("wait" => wait)
    response = _request(
        HTTP.put,
        client,
        "/collections/$collection/points",
        body;
        query=query
    )
    return _parse_response(response, Dict)
end

"""
    delete_points(client::Client, collection::String, points::Union{Vector{PointId}, Filter};
                  wait::Bool=true)

Delete points from a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `points::Union{Vector{PointId}, Filter}`: Point IDs to delete or filter
- `wait::Bool`: Whether to wait for the operation to complete

# Returns
Dict with operation status
"""
function delete_points(
    client::Client,
    collection::String,
    points::Union{AbstractVector{<:PointId}, Filter};
    wait::Bool=true
)
    body = _selector_body(points)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/delete",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

delete_points(client::Client, collection::String, point::PointId; kwargs...) =
    delete_points(client, collection, [point]; kwargs...)

"""
    retrieve_points(client::Client, collection::String, ids::Vector{PointId};
                    with_vectors::Bool=false, with_payload::Bool=true)

Retrieve specific points from a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `ids::Vector{PointId}`: Point IDs to retrieve
- `with_vectors::Bool`: Include vectors in response
- `with_payload::Bool`: Include payloads in response

# Returns
Vector of PointStruct objects
"""
function retrieve_points(
    client::Client,
    collection::String,
    ids::AbstractVector{<:PointId};
    with_vectors::Bool=false,
    with_payload::Bool=true
)
    body = _points_payload(ids; with_vectors=with_vectors, with_payload=with_payload)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points",
        body
    )
    return _point_results(_parse_response(response, Dict))
end

retrieve_points(client::Client, collection::String, id::PointId; kwargs...) =
    retrieve_points(client, collection, [id]; kwargs...)

"""
    batch_points(client::Client, collection::String, operations::Vector{Dict};
                 wait::Bool=true)

Perform batch operations on points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `operations::Vector{Dict}`: Batch operations
- `wait::Bool`: Whether to wait for operations to complete

# Returns
Vector of operation status dicts
"""
function batch_points(
    client::Client,
    collection::String,
    operations::Vector{Dict};
    wait::Bool=true
)
    body = Dict("operations" => operations)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/batch",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

"""
    scroll_points(client::Client, collection::String;
                  filter::Union{Filter, Nothing}=nothing,
                  limit::Int=10,
                  offset::Union{String, Nothing}=nothing,
                  with_vectors::Bool=false,
                  with_payload::Bool=true)

Scroll through points in a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `filter::Union{Filter, Nothing}`: Optional filter
- `limit::Int`: Maximum number of points to return per page
- `offset::Union{String, Nothing}`: Offset for pagination
- `with_vectors::Bool`: Include vectors in response
- `with_payload::Bool`: Include payloads in response

# Returns
ScrollResponse with points and next page offset
"""
function scroll_points(
    client::Client,
    collection::String;
    filter::Union{Filter, Nothing}=nothing,
    limit::Int=10,
    offset::Union{String, Nothing}=nothing,
    with_vectors::Bool=false,
    with_payload::Bool=true
)
    body = Dict{String, Any}(
        "limit" => limit,
        "with_vectors" => with_vectors,
        "with_payload" => with_payload
    )

    if !isnothing(filter)
        body["filter"] = QdrantClient._struct_to_dict(filter)
    end
    if !isnothing(offset)
        body["offset"] = offset
    end

    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/scroll",
        body
    )
    return _parse_response(response, ScrollResponse)
end

"""
    count_points(client::Client, collection::String;
                 filter::Union{Filter, Nothing}=nothing,
                 exact::Bool=false)

Count points in a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `filter::Union{Filter, Nothing}`: Optional filter
- `exact::Bool`: Return exact count or approximate

# Returns
CountResponse with point count
"""
function count_points(
    client::Client,
    collection::String;
    filter::Union{Filter, Nothing}=nothing,
    exact::Bool=false
)
    body = Dict{String, Any}("exact" => exact)

    if !isnothing(filter)
        body["filter"] = QdrantClient._struct_to_dict(filter)
    end

    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/count",
        body
    )
    return _parse_response(response, CountResponse)
end

"""
    set_payload(client::Client, collection::String, payload::Dict,
                points::Union{Vector{PointId}, Filter};
                wait::Bool=true)

Set payload for points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `payload::Dict`: Payload to set
- `points::Union{Vector{PointId}, Filter}`: Point IDs or filter
- `wait::Bool`: Whether to wait for operation to complete

# Returns
Dict with operation status
"""
function set_payload(
    client::Client,
    collection::String,
    payload::Dict,
    points::Union{AbstractVector{<:PointId}, Filter};
    wait::Bool=true
)
    body = merge(Dict{String, Any}("payload" => payload), _selector_body(points))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/payload",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

set_payload(client::Client, collection::String, payload::Dict, point::PointId; kwargs...) =
    set_payload(client, collection, payload, [point]; kwargs...)

"""
    delete_payload(client::Client, collection::String, keys::Vector{String},
                   points::Union{Vector{PointId}, Filter};
                   wait::Bool=true)

Delete payload fields from points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `keys::Vector{String}`: Payload keys to delete
- `points::Union{Vector{PointId}, Filter}`: Point IDs or filter
- `wait::Bool`: Whether to wait for operation to complete

# Returns
Dict with operation status
"""
function delete_payload(
    client::Client,
    collection::String,
    keys::Vector{String},
    points::Union{AbstractVector{<:PointId}, Filter};
    wait::Bool=true
)
    body = merge(Dict{String, Any}("keys" => keys), _selector_body(points))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/payload/delete",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

delete_payload(client::Client, collection::String, keys::Vector{String}, point::PointId; kwargs...) =
    delete_payload(client, collection, keys, [point]; kwargs...)

"""
    clear_payload(client::Client, collection::String,
                  points::Union{Vector{PointId}, Filter};
                  wait::Bool=true)

Clear all payload from points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `points::Union{Vector{PointId}, Filter}`: Point IDs or filter
- `wait::Bool`: Whether to wait for operation to complete

# Returns
Dict with operation status
"""
function clear_payload(
    client::Client,
    collection::String,
    points::Union{AbstractVector{<:PointId}, Filter};
    wait::Bool=true
)
    body = _selector_body(points)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/payload/clear",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

clear_payload(client::Client, collection::String, point::PointId; kwargs...) =
    clear_payload(client, collection, [point]; kwargs...)

"""
    update_vectors(client::Client, collection::String, points::Vector{PointStruct};
                   wait::Bool=true)

Update vectors for existing points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `points::Vector{PointStruct}`: Points with updated vectors
- `wait::Bool`: Whether to wait for operation to complete

# Returns
Dict with operation status
"""
function update_vectors(
    client::Client,
    collection::String,
    points::Vector{PointStruct};
    wait::Bool=true
)
    body = Dict(
        "points" => [QdrantClient._struct_to_dict(p) for p in points]
    )
    response = _request(
        HTTP.put,
        client,
        "/collections/$collection/points/vectors",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

"""
    delete_vectors(client::Client, collection::String, vector_names::Vector{String},
                   points::Union{Vector{PointId}, Filter};
                   wait::Bool=true)

Delete vector fields from points.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `vector_names::Vector{String}`: Names of vectors to delete
- `points::Union{Vector{PointId}, Filter}`: Point IDs or filter
- `wait::Bool`: Whether to wait for operation to complete

# Returns
Dict with operation status
"""
function delete_vectors(
    client::Client,
    collection::String,
    vector_names::Vector{String},
    points::Union{AbstractVector{<:PointId}, Filter};
    wait::Bool=true
)
    body = merge(Dict{String, Any}("vector_names" => vector_names), _selector_body(points))
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/points/vectors/delete",
        body;
        query=_wait_query(wait)
    )
    return _parse_response(response, Dict)
end

delete_vectors(client::Client, collection::String, vector_names::Vector{String}, point::PointId; kwargs...) =
    delete_vectors(client, collection, vector_names, [point]; kwargs...)
