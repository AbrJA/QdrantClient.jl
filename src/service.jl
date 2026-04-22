# ============================================================================
# Service API — HTTP transport
# ============================================================================

"""
    health_check(client) -> QdrantResponse{HealthInfo}

Check server health.
"""
function health_check(client::QdrantClient{HTTPTransport}=get_client())
    try
        resp = http_request(HTTP.get, client, "/")
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
    get_version(client) -> QdrantResponse{HealthInfo}

Get Qdrant server version and title.
"""
function get_version(client::QdrantClient{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, client, "/")
    raw, status, time = _unwrap(resp)
    info = raw isa AbstractDict ?
        HealthInfo(String(get(raw, "title", "qdrant")),
                   String(get(raw, "version", "unknown"))) :
        HealthInfo("qdrant", "unknown")
    QdrantResponse(info, status, time)
end

"""
    get_metrics(client) -> QdrantResponse{String}

Retrieve Prometheus-format metrics (plain text response).
"""
function get_metrics(client::QdrantClient{HTTPTransport}=get_client();
                     timeout::Optional{Int}=nothing)
    resp = http_request(HTTP.get, client, "/metrics"; query=_timeout_query(timeout))
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    get_telemetry(client) -> QdrantResponse{Dict{String,Any}}

Retrieve telemetry data.
"""
function get_telemetry(client::QdrantClient{HTTPTransport}=get_client();
                       timeout::Optional{Int}=nothing)
    resp = http_request(HTTP.get, client, "/telemetry"; query=_timeout_query(timeout))
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

# ── Kubernetes Health Probes ─────────────────────────────────────────────

"""
    healthz(client) -> QdrantResponse{String}

Kubernetes health check endpoint (plain text response).
"""
function healthz(client::QdrantClient{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, client, "/healthz")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    livez(client) -> QdrantResponse{String}

Kubernetes liveness probe (plain text response).
"""
function livez(client::QdrantClient{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, client, "/livez")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

"""
    readyz(client) -> QdrantResponse{String}

Kubernetes readiness probe (plain text response).
"""
function readyz(client::QdrantClient{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, client, "/readyz")
    QdrantResponse(String(resp.body), "", 0.0)  # plain text, no status field
end

# ── Issues ───────────────────────────────────────────────────────────────

"""
    get_issues(client) -> QdrantResponse{Dict{String,Any}}

Get performance issues and configuration suggestions.
"""
function get_issues(client::QdrantClient{HTTPTransport}=get_client())
    resp = http_request(HTTP.get, client, "/issues")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end

"""
    clear_issues(client) -> QdrantResponse{Bool}

Clear all reported issues.
"""
function clear_issues(client::QdrantClient{HTTPTransport}=get_client())
    parse_bool(http_request(HTTP.delete, client, "/issues"))
end
