# ============================================================================
# Service API (Health, Metrics, Telemetry)
# ============================================================================

"""
    health_check(client::Client)

Perform a health check on the Qdrant server.

# Arguments
- `client::Client`: The Qdrant client

# Returns
Dict with health status
"""
function health_check(client::Client=get_global_client())
    try
        response = _request(HTTP.get, client, "/collections")
        return Dict("status" => "healthy", "response" => _parse_response(response, Dict))
    catch e
        return Dict("status" => "unhealthy", "error" => string(e))
    end
end

"""
    get_metrics(client::Client)

Get metrics information from the Qdrant server.

# Arguments
- `client::Client`: The Qdrant client

# Returns
MetricsData with server metrics
"""
function get_metrics(client::Client=get_global_client())
    response = _request(HTTP.get, client, "/metrics")
    return _parse_response(response, MetricsData)
end

"""
    get_telemetry(client::Client)

Get telemetry information from the Qdrant server.

# Arguments
- `client::Client`: The Qdrant client

# Returns
TelemetryData with server telemetry
"""
function get_telemetry(client::Client=get_global_client())
    response = _request(HTTP.get, client, "/telemetry")
    return _parse_response(response, TelemetryData)
end
