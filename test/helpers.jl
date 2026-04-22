# ============================================================================
# Shared test helpers
# ============================================================================

using Test
using UUIDs
using HTTP
using JSON
using Qdrant

const CONN = QdrantClient()

unique_name(prefix="jl") = string(prefix, "_", replace(string(uuid4()), "-" => ""))

function qdrant_available(client::QdrantClient=CONN)
    try
        # `health_check` is intentionally forgiving and returns a fallback response on connection errors.
        resp = get_version(client)
        resp.status == "ok" && !isempty(resp.result.version)
    catch
        false
    end
end

function cleanup_collection(client::QdrantClient, name)
    try; delete_collection(client, name); catch; end
end

function cleanup_alias(client::QdrantClient, alias)
    try; delete_alias(client, alias); catch; end
end

function fixture_points()
    [
        Point(id=1, vector=Float32[1.0, 0.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 1)),
        Point(id=2, vector=Float32[0.9, 0.1, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "a", "n" => 2)),
        Point(id=3, vector=Float32[0.0, 1.0, 0.0, 0.0],
              payload=Dict{String,Any}("group" => "b", "n" => 3)),
    ]
end
