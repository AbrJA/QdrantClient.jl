"""
    QdrantClient

A Julian client for the [Qdrant](https://qdrant.tech) vector database.

Leverages `StructUtils.jl` for zero-cost struct ↔ JSON mapping and an abstract
transport layer for future gRPC support.

# Quick Start
```julia
using QdrantClient

client = QdrantConnection()
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
upsert_points(client, "demo", [PointStruct(id=1, vector=Float32[1,0,0,0])])
query_points(client, "demo", QueryRequest(query=Float32[1,0,0,0], limit=5))
```
"""
module QdrantClient

using HTTP
using JSON
using StructUtils
using UUIDs

const CLIENT_VERSION = "0.3.0"

# ── Error type ───────────────────────────────────────────────────────────
include("error.jl")

# ── Type hierarchy ───────────────────────────────────────────────────────
include("types.jl")

# ============================================================================
# Transport Abstraction
# ============================================================================

"""
    AbstractTransport

Abstract transport layer. Subtype this to add gRPC or other backends.
"""
abstract type AbstractTransport end

"""
    HTTPTransport <: AbstractTransport

HTTP/REST transport using HTTP.jl with connection pooling.
"""
mutable struct HTTPTransport <: AbstractTransport
    host::String
    port::Int
    api_key::Optional{String}
    timeout::Int
    tls::Bool
    pool::Optional{HTTP.Pool}
end

function HTTPTransport(;
    host::String="localhost",
    port::Int=6333,
    api_key::Optional{String}=nothing,
    timeout::Int=30,
    tls::Bool=false,
)
    HTTPTransport(host, port, api_key, timeout, tls, nothing)
end

function ensure_pool!(transport::HTTPTransport)
    transport.pool === nothing && (transport.pool = HTTP.Pool())
    transport.pool
end

function base_url(transport::HTTPTransport)
    scheme = transport.tls ? "https" : "http"
    "$scheme://$(transport.host):$(transport.port)"
end

function transport_headers(transport::HTTPTransport)
    headers = [
        "Content-Type" => "application/json",
        "User-Agent" => "QdrantClient.jl/$CLIENT_VERSION",
    ]
    transport.api_key !== nothing && push!(headers, "api-key" => transport.api_key)
    headers
end

function transport_url(transport::HTTPTransport, path::AbstractString)
    p = startswith(path, '/') ? path[2:end] : path
    "$(base_url(transport))/$p"
end

# ============================================================================
# QdrantConnection — the main client
# ============================================================================

"""
    QdrantConnection

Connection to a Qdrant server backed by an `AbstractTransport`.

# Constructors
```julia
QdrantConnection()                          # localhost:6333
QdrantConnection(host="myhost", port=6334)  # custom host/port
QdrantConnection(transport)                 # custom transport
```
"""
struct QdrantConnection
    transport::AbstractTransport
end

function QdrantConnection(;
    host::String="localhost",
    port::Int=6333,
    api_key::Optional{String}=nothing,
    timeout::Int=30,
    tls::Bool=false,
)
    QdrantConnection(HTTPTransport(; host, port, api_key, timeout, tls))
end

# Backward compat alias
const Client = QdrantConnection

const _GLOBAL_CLIENT = Ref{QdrantConnection}()

"""
    set_client!(c::QdrantConnection) -> QdrantConnection

Set the global default client.
"""
function set_client!(conn::QdrantConnection)
    _GLOBAL_CLIENT[] = conn
    conn
end

"""
    get_client() -> QdrantConnection

Return the global default client, creating one if needed.
"""
function get_client()
    isassigned(_GLOBAL_CLIENT) || (_GLOBAL_CLIENT[] = QdrantConnection())
    _GLOBAL_CLIENT[]
end

# ============================================================================
# Serialization — powered by JSON.jl + StructUtils
# ============================================================================

const _JSON_KW = (omit_null=true, omit_empty=true)

"""
    serialize_body(x) -> String

Serialize a value to JSON, stripping `nothing` fields and empty collections.
"""
serialize_body(x::AbstractQdrantType) = JSON.json(x; _JSON_KW...)
serialize_body(x::AbstractDict) = JSON.json(x; _JSON_KW...)
serialize_body(x) = JSON.json(x; _JSON_KW...)

# ============================================================================
# HTTP Request Infrastructure
# ============================================================================

function parse_error(resp::HTTP.Response)
    status = Int(resp.status)
    body = String(resp.body)
    isempty(body) && return QdrantError(status, "API error $status")
    try
        parsed = JSON.parse(body)
        st = get(parsed, "status", nothing)
        if st isa AbstractDict && haskey(st, "error")
            return QdrantError(status, string(st["error"]), parsed)
        end
        return QdrantError(status, "API error $status", parsed)
    catch
        return QdrantError(status, "API error $status: $(first(body, 200))")
    end
end

"""
    request(method, client, path, [body]; query=nothing) -> HTTP.Response

Low-level HTTP request with error handling and connection pooling.
"""
function request(method::Function, conn::QdrantConnection, path::AbstractString, body=nothing; query=nothing)
    transport = conn.transport::HTTPTransport
    url = transport_url(transport, path)
    kw = Dict{Symbol,Any}(
        :pool => ensure_pool!(transport),
        :headers => transport_headers(transport),
        :status_exception => false,
    )
    query !== nothing && (kw[:query] = query)
    if body !== nothing
        kw[:body] = if body isa AbstractString
            body
        else
            serialize_body(body)
        end
    end
    resp = method(url; kw...)
    resp.status >= 400 && throw(parse_error(resp))
    resp
end

"""
    parse_response(resp::HTTP.Response)

Parse the JSON response, unwrapping Qdrant's `{status, time, result}` envelope.
"""
function parse_response(resp::HTTP.Response)
    b = String(resp.body)
    isempty(b) && return nothing
    parsed = JSON.parse(b)
    haskey(parsed, "result") ? parsed["result"] : parsed
end

"""
    execute(method, client, path, [body]; query=nothing)

Combined request + parse_response in one call.
"""
function execute(method::Function, conn::QdrantConnection, path::AbstractString, body=nothing; query=nothing)
    parse_response(request(method, conn, path, body; query))
end

# ── API modules ──────────────────────────────────────────────────────────
include("collections.jl")
include("points.jl")
include("search.jl")
include("discovery.jl")
include("snapshots.jl")
include("distributed.jl")
include("service.jl")

# ============================================================================
# Exports
# ============================================================================

# Core
export QdrantConnection, Client, set_client!, get_client, QdrantError

# Transport
export AbstractTransport, HTTPTransport

# Type hierarchy
export AbstractQdrantType, AbstractConfig, AbstractRequest, AbstractCondition

# Type alias
export Optional

# Enum & aliases
export Distance, Cosine, Euclid, Dot, Manhattan, PointId

# Config types
export CollectionConfig, CollectionUpdate, VectorParams, SparseVectorParams
export HnswConfig, WalConfig, OptimizersConfig, CollectionParamsDiff
export SearchParams, QuantizationSearchParams
export ScalarQuantization, ScalarQuantizationConfig
export ProductQuantization, ProductQuantizationConfig
export BinaryQuantization, BinaryQuantizationConfig
export QuantizationConfig, LookupLocation

# Point types
export PointStruct, NamedVector

# Conditions
export Filter, FieldCondition, MatchValue, MatchAny, MatchText,
       RangeCondition, HasIdCondition, IsEmptyCondition, IsNullCondition

# Request types
export SearchRequest, RecommendRequest, QueryRequest, DiscoverRequest

# Payload index types
export TextIndexParams

# Serialization
export serialize_body

# Collections API
export list_collections, create_collection, delete_collection,
       collection_exists, get_collection, update_collection,
       list_aliases, create_alias, delete_alias, rename_alias,
       list_collection_aliases

# Points API
export upsert_points, delete_points, get_points, set_payload,
       delete_payload, clear_payload, update_vectors, delete_vectors,
       scroll_points, count_points, batch_points

# Search API
export search_points, search_batch, search_groups,
       recommend_points, recommend_batch, recommend_groups,
       query_points, query_batch, query_groups

# Discovery API
export discover_points, discover_batch

# Snapshots API
export create_snapshot, list_snapshots, delete_snapshot

# Service API
export health_check, get_metrics, get_telemetry

# Distributed API
export cluster_status

# Payload Index API
export create_payload_index, delete_payload_index

end # module
