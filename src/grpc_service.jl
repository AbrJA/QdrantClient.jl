# ============================================================================
# gRPC Service API — dispatch on GRPCTransport
# ============================================================================

function health_check(c::QdrantConnection, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    try
        resp = grpc_request(transport, Qdrant_HealthCheck_Client, qdrant.HealthCheckRequest())
        HealthResponse(resp.title, resp.version)
    catch
        HealthResponse("qdrant", "unavailable")
    end
end
