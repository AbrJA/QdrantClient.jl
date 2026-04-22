# ============================================================================
# Distributed / Cluster API
# ============================================================================

"""
    cluster_status(client) -> Dict{String,Any}

Get cluster status information.
"""
function cluster_status(c::QdrantConnection=get_client())
    resp = request(HTTP.get, c, "/cluster")
    parse_response(resp)
end
