# ============================================================================
# Service API — HTTP transport
# ============================================================================

"""
    health_check(conn) -> QdrantResponse{HealthInfo}

Check server health.
"""
function health_check(conn::QdrantConnection{HTTPTransport}=get_client())
    try
        resp = http_request(HTTP.get, conn, "/")
        raw, status, time = _unwrap(resp)
        info = raw isa AbstractDict ?
            HealthInfo(String(get(raw, "title", "qdrant")),
                       String(get(raw, "version", "unknown"))) :
            HealthInfo("qdrant", "unknown")
        QdrantResponse(info, status, time)
    catch
        QdrantResponse(HealthInfo("qdrant", "unavailable"), "error", 0.0)
    end
end

"""
    get_version(conn) -> QdrantResponse{HealthInfo}

Get Qdrant server version and title.
"""
function get_version(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/")
    raw, status, time = _unwrap(resp)
    info = raw isa AbstractDict ?
        HealthInfo(String(get(raw, "title", "qdrant")),
                   String(get(raw, "version", "unknown"))) :
        HealthInfo("qdrant", "unknown")
    QdrantResponse(info, status, time)
end

"""
    get_metrics(conn) -> QdrantResponse{String}

Retrieve Prometheus-format metrics.
"""
function get_metrics(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/metrics")
    QdrantResponse(String(resp.body), "ok", 0.0)
end

"""
    get_telemetry(conn) -> QdrantResponse{Dict{String,Any}}

Retrieve telemetry data.
"""
function get_telemetry(conn::QdrantConnection{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, conn, "/telemetry")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
