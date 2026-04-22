# ============================================================================
# Service API (Health, Metrics, Telemetry, Version)
# ============================================================================

"""
    health_check(client) -> HealthResponse

Check server health. Returns a `HealthResponse` with title and version.
"""
function health_check(c::QdrantConnection=get_client())
    is_grpc(c) && return health_check(c, Val(:grpc))
    try
        resp = request(HTTP.get, c, "/")
        r = parse_response(resp)
        r isa AbstractDict || return HealthResponse("qdrant", "unknown")
        HealthResponse(
            get(r, "title", "qdrant")::String,
            get(r, "version", "unknown")::String,
        )
    catch
        HealthResponse("qdrant", "unavailable")
    end
end

"""
    get_version(client) -> HealthResponse

Get Qdrant server version and title.
"""
function get_version(c::QdrantConnection=get_client())
    resp = request(HTTP.get, c, "/")
    r = parse_response(resp)
    r isa AbstractDict || return HealthResponse("qdrant", "unknown")
    HealthResponse(
        get(r, "title", "qdrant")::String,
        get(r, "version", "unknown")::String,
    )
end

"""
    get_metrics(client) -> String

Retrieve Prometheus-format metrics from the server.
"""
function get_metrics(c::QdrantConnection=get_client())
    resp = request(HTTP.get, c, "/metrics")
    String(resp.body)
end

"""
    get_telemetry(client) -> Dict{String,Any}

Retrieve telemetry data from the server.
"""
function get_telemetry(c::QdrantConnection=get_client())
    resp = request(HTTP.get, c, "/telemetry")
    parse_response(resp)
end
