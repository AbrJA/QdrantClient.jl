# ============================================================================
# Snapshots API
# ============================================================================

"""
    create_snapshot(client::Client, collection::String)

Create a snapshot of a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name

# Returns
Dict with snapshot information
"""
function create_snapshot(client::Client, collection::String)
    response = _request(
        HTTP.post,
        client,
        "/collections/$collection/snapshots"
    )
    return _parse_response(response, Dict)
end

"""
    list_snapshots(client::Client, collection::String)

List all snapshots for a collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name

# Returns
Vector of SnapshotDescription objects
"""
function list_snapshots(client::Client, collection::String)
    response = _request(
        HTTP.get,
        client,
        "/collections/$collection/snapshots"
    )
    parsed = _parse_response(response, Dict)
    return parsed isa AbstractVector ? parsed : get(parsed, :snapshots, Any[])
end

"""
    delete_snapshot(client::Client, collection::String, snapshot_name::String)

Delete a snapshot.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `snapshot_name::String`: Snapshot name

# Returns
Dict with operation status
"""
function delete_snapshot(
    client::Client,
    collection::String,
    snapshot_name::String
)
    response = _request(
        HTTP.delete,
        client,
        "/collections/$collection/snapshots/$snapshot_name"
    )
    return _parse_response(response, Dict)
end

"""
    recover_snapshot(client::Client, collection::String, snapshot_name::String;
                     priority::String="large_first")

Recover a collection from a snapshot.

# Arguments
- `client::Client`: The Qdrant client
- `collection::String`: Collection name
- `snapshot_name::String`: Snapshot name
- `priority::String`: Recovery priority ("large_first" or "small_first")

# Returns
Dict with operation status
"""
function recover_snapshot(
    client::Client,
    collection::String,
    snapshot_name::String;
    priority::String="large_first"
)
    body = Dict("priority" => priority)
    response = _request(
        HTTP.put,
        client,
        "/collections/$collection/snapshots/recover/$snapshot_name",
        body
    )
    return _parse_response(response, Dict)
end
