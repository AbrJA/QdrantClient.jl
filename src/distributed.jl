# ============================================================================
# Distributed API — HTTP transport
# ============================================================================

"""
    cluster_status(conn) -> QdrantResponse{Dict{String,Any}}

Get cluster status information.
"""
function cluster_status(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/cluster")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
