# ============================================================================
# Service API — gRPC transport
# ============================================================================

function health_check(client::QdrantClient{GRPCTransport})
    try
        resp = grpc_request(client.transport, Qdrant_HealthCheck_Client, qdrant.HealthCheckRequest())
        QdrantResponse(HealthInfo(resp.title, resp.version), "ok", 0.0)
    catch
        QdrantResponse(HealthInfo("qdrant", "unavailable"), "error", 0.0)
    end
end
