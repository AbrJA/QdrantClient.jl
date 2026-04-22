# ============================================================================
# Snapshots API — HTTP transport
# ============================================================================

"""
    create_snapshot(client, collection) -> QdrantResponse{SnapshotInfo}
"""
function create_snapshot(client::QdrantClient{HTTPTransport}, collection::AbstractString)
    parse_snapshot(http_request(HTTP.post, client, "/collections/$collection/snapshots"))
end
create_snapshot(collection::AbstractString) = create_snapshot(get_client(), collection)

"""
    list_snapshots(client, collection) -> QdrantResponse{Vector{SnapshotInfo}}
"""
function list_snapshots(client::QdrantClient{HTTPTransport}, collection::AbstractString)
    parse_snapshot_list(http_request(HTTP.get, client, "/collections/$collection/snapshots"))
end
list_snapshots(collection::AbstractString) = list_snapshots(get_client(), collection)

"""
    delete_snapshot(client, collection, snapshot_name) -> QdrantResponse{Bool}
"""
function delete_snapshot(client::QdrantClient{HTTPTransport}, collection::AbstractString,
                         name::AbstractString)
    parse_bool(http_request(HTTP.delete, client, "/collections/$collection/snapshots/$name"))
end
delete_snapshot(collection::AbstractString, name::AbstractString) =
    delete_snapshot(get_client(), collection, name)

# ── Full Storage Snapshots ───────────────────────────────────────────────

"""
    create_full_snapshot(client) -> QdrantResponse{SnapshotInfo}
"""
function create_full_snapshot(client::QdrantClient{HTTPTransport}=get_client())
    parse_snapshot(http_request(HTTP.post, client, "/snapshots"))
end

"""
    list_full_snapshots(client) -> QdrantResponse{Vector{SnapshotInfo}}
"""
function list_full_snapshots(client::QdrantClient{HTTPTransport}=get_client())
    parse_snapshot_list(http_request(HTTP.get, client, "/snapshots"))
end

"""
    delete_full_snapshot(client, snapshot_name) -> QdrantResponse{Bool}
"""
function delete_full_snapshot(client::QdrantClient{HTTPTransport}, name::AbstractString)
    parse_bool(http_request(HTTP.delete, client, "/snapshots/$name"))
end
delete_full_snapshot(name::AbstractString) = delete_full_snapshot(get_client(), name)

# ── Snapshot Recovery ────────────────────────────────────────────────────

"""
    recover_from_snapshot(client, collection; location, priority) -> QdrantResponse{Bool}

Recover a collection from a snapshot URL or local path.

# Examples
```julia
recover_from_snapshot(client, "demo"; location="http://host/snapshot.tar")
recover_from_snapshot(client, "demo"; location="file:///data/snapshot.tar")
```
"""
function recover_from_snapshot(client::QdrantClient{HTTPTransport},
                               collection::AbstractString;
                               location::AbstractString,
                               priority::Optional{String}=nothing)
    body = Dict{String,Any}("location" => location)
    priority !== nothing && (body["priority"] = priority)
    parse_bool(http_request(HTTP.put, client, "/collections/$collection/snapshots/recover", body))
end
recover_from_snapshot(collection::AbstractString; kw...) =
    recover_from_snapshot(get_client(), collection; kw...)
