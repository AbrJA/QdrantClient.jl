# ============================================================================
# QdrantClient.jl v1.0 — Test Suite
# ============================================================================

include("helpers.jl")

@testset "QdrantClient.jl v1.0" begin

include("test_types.jl")
include("test_integration.jl")

end  # QdrantClient.jl v1.0

include("test_grpc.jl")
