# ============================================================================
# Distributed API — HTTP transport
# ============================================================================

"""
    cluster_status(client) -> QdrantResponse{ClusterStatus}

Get cluster status information.
"""
function cluster_status(client::QdrantClient{HTTPTransport}=get_client())
    parse_cluster_status(http_request(HTTP.get, client, "/cluster"))
end

"""
    cluster_telemetry(client) -> QdrantResponse{Dict{String,Any}}

Get cluster-wide telemetry (peers, collections, shard transfers).
"""
function cluster_telemetry(client::QdrantClient{HTTPTransport}=get_client();
                           timeout::Optional{Int}=nothing)
    resp = http_request(HTTP.get, client, "/cluster/telemetry";
                        query=_timeout_query(timeout))
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

"""
    recover_current_peer(client) -> QdrantResponse{Bool}

Attempt to recover the current peer.
"""
function recover_current_peer(client::QdrantClient{HTTPTransport}=get_client())
    parse_bool(http_request(HTTP.post, client, "/cluster/recover"))
end

"""
    remove_peer(client, peer_id; force=false) -> QdrantResponse{Bool}

Remove a peer from the cluster. Fails if peer still has shards.
"""
function remove_peer(client::QdrantClient{HTTPTransport}, peer_id::Integer;
                     force::Bool=false, timeout::Optional{Int}=nothing)
    q = Dict{String,Any}()
    force && (q["force"] = "true")
    timeout !== nothing && (q["timeout"] = timeout)
    kw = isempty(q) ? (;) : (; query=q)
    parse_bool(http_request(HTTP.delete, client, "/cluster/peer/$peer_id"; kw...))
end

"""
    collection_cluster_info(client, collection) -> QdrantResponse{CollectionClusterInfo}

Get cluster information for a collection.
"""
function collection_cluster_info(client::QdrantClient{HTTPTransport}, name::AbstractString)
    parse_collection_cluster_info(http_request(HTTP.get, client, "/collections/$name/cluster"))
end
collection_cluster_info(name::AbstractString) = collection_cluster_info(get_client(), name)

"""
    update_collection_cluster(client, collection, operations) -> QdrantResponse{Bool}

Update collection cluster configuration (move/replicate shards).
"""
function update_collection_cluster(client::QdrantClient{HTTPTransport},
                                   name::AbstractString, body::AbstractDict;
                                   timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.post, client, "/collections/$name/cluster", body;
                            query=_timeout_query(timeout)))
end
update_collection_cluster(name::AbstractString, body::AbstractDict; kwargs...) =
    update_collection_cluster(get_client(), name, body; kwargs...)

# ── Shard Keys ───────────────────────────────────────────────────────────

"""
    list_shard_keys(client, collection) -> QdrantResponse{ShardKeysResult}

List shard keys for a collection.
"""
function list_shard_keys(client::QdrantClient{HTTPTransport}, name::AbstractString)
    parse_shard_keys(http_request(HTTP.get, client, "/collections/$name/shards"))
end
list_shard_keys(name::AbstractString) = list_shard_keys(get_client(), name)

"""
    create_shard_key(client, collection, request) -> QdrantResponse{Bool}

Create a shard key for a collection.
"""
function create_shard_key(client::QdrantClient{HTTPTransport},
                          name::AbstractString, body::AbstractDict;
                          timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.put, client, "/collections/$name/shards", body;
                            query=_timeout_query(timeout)))
end
create_shard_key(name::AbstractString, body::AbstractDict; kwargs...) =
    create_shard_key(get_client(), name, body; kwargs...)

"""
    delete_shard_key(client, collection, request) -> QdrantResponse{Bool}

Delete a shard key from a collection.
"""
function delete_shard_key(client::QdrantClient{HTTPTransport},
                          name::AbstractString, body::AbstractDict;
                          timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.post, client, "/collections/$name/shards/delete", body;
                            query=_timeout_query(timeout)))
end
delete_shard_key(name::AbstractString, body::AbstractDict; kwargs...) =
    delete_shard_key(get_client(), name, body; kwargs...)

# ── Shard Snapshots ──────────────────────────────────────────────────────

"""
    create_shard_snapshot(client, collection, shard_id) -> QdrantResponse{SnapshotInfo}

Create a snapshot for a specific shard.
"""
function create_shard_snapshot(client::QdrantClient{HTTPTransport},
                               name::AbstractString, shard_id::Integer)
    parse_snapshot(http_request(HTTP.post, client, "/collections/$name/shards/$shard_id/snapshots"))
end

"""
    list_shard_snapshots(client, collection, shard_id) -> QdrantResponse{Vector{SnapshotInfo}}

List snapshots for a specific shard.
"""
function list_shard_snapshots(client::QdrantClient{HTTPTransport},
                              name::AbstractString, shard_id::Integer)
    parse_snapshot_list(http_request(HTTP.get, client, "/collections/$name/shards/$shard_id/snapshots"))
end

"""
    delete_shard_snapshot(client, collection, shard_id, snapshot_name) -> QdrantResponse{Bool}

Delete a snapshot for a specific shard.
"""
function delete_shard_snapshot(client::QdrantClient{HTTPTransport},
                               name::AbstractString, shard_id::Integer,
                               snapshot_name::AbstractString)
    parse_bool(http_request(HTTP.delete, client,
        "/collections/$name/shards/$shard_id/snapshots/$snapshot_name"))
end
