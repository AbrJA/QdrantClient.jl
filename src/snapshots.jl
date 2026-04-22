# ============================================================================
# Snapshots API — collection, full storage
# ============================================================================

"""
    create_snapshot(client, collection) -> SnapshotInfo

Create a snapshot of a collection.
"""
function create_snapshot(c::QdrantConnection, collection::AbstractString)
    is_grpc(c) && return create_snapshot(c, collection, Val(:grpc))
    parse_snapshot(request(HTTP.post, c, "/collections/$collection/snapshots"))
end
create_snapshot(collection::AbstractString) = create_snapshot(get_client(), collection)

"""
    list_snapshots(client, collection) -> Vector{SnapshotInfo}

List all snapshots for a collection.
"""
function list_snapshots(c::QdrantConnection, collection::AbstractString)
    is_grpc(c) && return list_snapshots(c, collection, Val(:grpc))
    parse_snapshot_list(request(HTTP.get, c, "/collections/$collection/snapshots"))
end
list_snapshots(collection::AbstractString) = list_snapshots(get_client(), collection)

"""
    delete_snapshot(client, collection, snapshot_name) -> Bool

Delete a snapshot.
"""
function delete_snapshot(c::QdrantConnection, collection::AbstractString, name::AbstractString)
    is_grpc(c) && return delete_snapshot(c, collection, name, Val(:grpc))
    parse_bool(request(HTTP.delete, c, "/collections/$collection/snapshots/$name"))
end
delete_snapshot(collection::AbstractString, name::AbstractString) =
    delete_snapshot(get_client(), collection, name)

# ── Full Storage Snapshots ───────────────────────────────────────────────

"""
    create_full_snapshot(client) -> SnapshotInfo

Create a snapshot of the entire Qdrant storage.
"""
function create_full_snapshot(c::QdrantConnection=get_client())
    parse_snapshot(request(HTTP.post, c, "/snapshots"))
end

"""
    list_full_snapshots(client) -> Vector{SnapshotInfo}

List all full storage snapshots.
"""
function list_full_snapshots(c::QdrantConnection=get_client())
    parse_snapshot_list(request(HTTP.get, c, "/snapshots"))
end

"""
    delete_full_snapshot(client, snapshot_name) -> Bool

Delete a full storage snapshot.
"""
function delete_full_snapshot(c::QdrantConnection, name::AbstractString)
    parse_bool(request(HTTP.delete, c, "/snapshots/$name"))
end
delete_full_snapshot(name::AbstractString) = delete_full_snapshot(get_client(), name)
