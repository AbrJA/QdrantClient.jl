# ============================================================================
# Distributed Operations API
# ============================================================================

"""
    cluster_status(client::Client)

Get cluster status information.

# Arguments
- `client::Client`: The Qdrant client

# Returns
ClusterStatus with cluster information
"""
function cluster_status(client::Client=get_global_client())
    response = _request(HTTP.get, client, "/cluster")
    return _parse_response(response, ClusterStatus)
end

"""
    get_peer(client::Client, peer_id::Int)

Get information about a specific peer in the cluster.

# Arguments
- `client::Client`: The Qdrant client
- `peer_id::Int`: Peer ID

# Returns
Dict with peer information
"""
function get_peer(client::Client, peer_id::Int)
    response = _request(HTTP.get, client, "/cluster/peer/$peer_id")
    return _parse_response(response, Dict)
end

"""
    recover_peer(client::Client, peer_id::Int)

Attempt to recover a peer in the cluster.

# Arguments
- `client::Client`: The Qdrant client
- `peer_id::Int`: Peer ID to recover

# Returns
Dict with operation status
"""
function recover_peer(client::Client, peer_id::Int)
    response = _request(HTTP.post, client, "/cluster/recover/$peer_id")
    return _parse_response(response, Dict)
end
