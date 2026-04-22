# ============================================================================
# Shared test helpers
# ============================================================================

using Test
using UUIDs
using HTTP
using JSON
using QdrantClient

const CONN = QdrantConnection()

unique_name(prefix="jl") = string(prefix, "_", replace(string(uuid4()), "-" => ""))

function qdrant_available(conn::QdrantConnection=CONN)
    try
        health_check(conn)
        true
    catch
        false
    end
end

function cleanup_collection(conn::QdrantConnection, name)
    try; delete_collection(conn, name); catch; end
end

function cleanup_alias(conn::QdrantConnection, alias)
    try; delete_alias(conn, alias); catch; end
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
