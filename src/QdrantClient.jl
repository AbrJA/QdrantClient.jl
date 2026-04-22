"""
    QdrantClient

A Julian client for the [Qdrant](https://qdrant.tech) vector database.

Supports both HTTP/REST and gRPC transports for maximum flexibility and performance.
Leverages `StructUtils.jl` for zero-cost struct ↔ JSON mapping and `gRPCClient.jl`
with `ProtoBuf.jl` for high-performance binary protocol communication.

# Quick Start — HTTP (default)
```julia
using QdrantClient

client = QdrantConnection()  # localhost:6333 HTTP
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
upsert_points(client, "demo", [Point(id=1, vector=Float32[1,0,0,0])])
query_points(client, "demo", QueryRequest(query=Float32[1,0,0,0], limit=5))
```

# Quick Start — gRPC (~2-10x faster for bulk operations)
```julia
using QdrantClient

client = QdrantConnection(GRPCTransport(host="localhost", port=6334))
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
upsert_points(client, "demo", [Point(id=1, vector=Float32[1,0,0,0])])
query_points(client, "demo", QueryRequest(query=Float32[1,0,0,0], limit=5))
```
"""
module QdrantClient

using HTTP
using JSON
using StructUtils
using UUIDs
using ProtoBuf: OneOf

const CLIENT_VERSION = "1.0.0"

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
    isassigned(_GLOBAL_CLIENT) ? _GLOBAL_CLIENT[] : (_GLOBAL_CLIENT[] = QdrantConnection())
end

# ============================================================================
# Serialization — powered by JSON.jl + StructUtils
# ============================================================================

const _JSON_KW = (omit_null=true, omit_empty=true)

"""
    serialize_body(x) -> String

Serialize a value to JSON, stripping `nothing` fields and empty collections.
"""
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
Returns the raw `result` value (or entire body if no envelope).
"""
function parse_response(resp::HTTP.Response)
    b = String(resp.body)
    isempty(b) && return nothing
    parsed = JSON.parse(b)
    haskey(parsed, "result") ? parsed["result"] : parsed
end

# ── Typed Response Constructors ──────────────────────────────────────────

"""
    parse_update(resp::HTTP.Response) -> UpdateResponse

Parse an update/mutation response into a typed `UpdateResponse`.
"""
function parse_update(resp::HTTP.Response)
    r = parse_response(resp)
    r === true && return UpdateResponse(0, "completed")
    r isa AbstractDict || return UpdateResponse(0, "completed")
    UpdateResponse(
        get(r, "operation_id", 0)::Union{Int,Int64},
        get(r, "status", "completed")::String,
    )
end

"""
    parse_bool(resp::HTTP.Response) -> Bool

Parse a boolean result.
"""
function parse_bool(resp::HTTP.Response)
    r = parse_response(resp)
    r === true
end

"""
    parse_records(resp::HTTP.Response) -> Vector{Record}

Parse an array of point records.
"""
function parse_records(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractVector || return Record[]
    Record[_dict_to_record(p) for p in r]
end

function _dict_to_record(d::AbstractDict)
    id = d["id"]
    pid = id isa Integer ? Int(id) : UUID(string(id))
    Record(
        pid,
        get(d, "payload", nothing),
        get(d, "vector", nothing),
    )
end

"""
    parse_scored_points(resp::HTTP.Response) -> Vector{ScoredPoint}

Parse an array of scored points (from deprecated search or query results).
"""
function parse_scored_points(raw)
    raw isa AbstractVector || return ScoredPoint[]
    ScoredPoint[_dict_to_scored(p) for p in raw]
end

function _dict_to_scored(d::AbstractDict)
    id = d["id"]
    pid = id isa Integer ? Int(id) : UUID(string(id))
    ScoredPoint(
        pid,
        get(d, "version", 0)::Union{Int,Int64},
        Float64(get(d, "score", 0.0)),
        get(d, "payload", nothing),
        get(d, "vector", nothing),
    )
end

function _dict_to_point_id(v)
    v isa Integer ? Int(v) : UUID(string(v))
end

"""
    parse_query(resp::HTTP.Response) -> QueryResponse

Parse a query_points response.
"""
function parse_query(resp::HTTP.Response)
    r = parse_response(resp)
    if r isa AbstractDict && haskey(r, "points")
        QueryResponse(parse_scored_points(r["points"]))
    elseif r isa AbstractVector
        QueryResponse(parse_scored_points(r))
    else
        QueryResponse(ScoredPoint[])
    end
end

"""
    parse_scroll(resp::HTTP.Response) -> ScrollResponse

Parse a scroll_points response.
"""
function parse_scroll(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractDict || return ScrollResponse(Record[], nothing)
    points = haskey(r, "points") ? Record[_dict_to_record(p) for p in r["points"]] : Record[]
    offset_raw = get(r, "next_page_offset", nothing)
    offset = offset_raw === nothing ? nothing : _dict_to_point_id(offset_raw)
    ScrollResponse(points, offset)
end

"""
    parse_count(resp::HTTP.Response) -> CountResponse

Parse a count_points response.
"""
function parse_count(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractDict || return CountResponse(0)
    CountResponse(Int(get(r, "count", 0)))
end

"""
    parse_groups(resp::HTTP.Response) -> GroupsResponse

Parse a query_groups response.
"""
function parse_groups(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractDict || return GroupsResponse(GroupResult[])
    raw_groups = get(r, "groups", Any[])
    groups = GroupResult[]
    for g in raw_groups
        gid = get(g, "id", nothing)
        hits = parse_scored_points(get(g, "hits", Any[]))
        push!(groups, GroupResult(gid, hits))
    end
    GroupsResponse(groups)
end

"""
    parse_snapshot(resp::HTTP.Response) -> SnapshotInfo

Parse a create/get snapshot response.
"""
function parse_snapshot(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractDict || return SnapshotInfo("", nothing, 0, nothing)
    SnapshotInfo(
        get(r, "name", "")::String,
        get(r, "creation_time", nothing),
        Int(get(r, "size", 0)),
        get(r, "checksum", nothing),
    )
end

"""
    parse_snapshot_list(resp::HTTP.Response) -> Vector{SnapshotInfo}

Parse a list_snapshots response.
"""
function parse_snapshot_list(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractVector || return SnapshotInfo[]
    SnapshotInfo[SnapshotInfo(
        get(s, "name", "")::String,
        get(s, "creation_time", nothing),
        Int(get(s, "size", 0)),
        get(s, "checksum", nothing),
    ) for s in r]
end

"""
    parse_facet(resp::HTTP.Response) -> FacetResponse

Parse a facet response.
"""
function parse_facet(resp::HTTP.Response)
    r = parse_response(resp)
    r isa AbstractDict || return FacetResponse(FacetHit[])
    raw_hits = get(r, "hits", Any[])
    FacetResponse(FacetHit[FacetHit(get(h, "value", nothing), Int(get(h, "count", 0))) for h in raw_hits])
end

# ── gRPC transport type (needed before API files for dispatch) ────────────
include("grpc_transport.jl")

"""
    is_grpc(c::QdrantConnection) -> Bool

Check if a connection uses gRPC transport.
"""
is_grpc(c::QdrantConnection) = c.transport isa GRPCTransport

# ── API modules (HTTP/REST + gRPC internal dispatch) ─────────────────────
include("collections.jl")
include("points.jl")
include("query.jl")
include("snapshots.jl")
include("distributed.jl")
include("service.jl")

# ── gRPC API implementations ────────────────────────────────────────────
include("grpc_collections.jl")
include("grpc_points.jl")
include("grpc_query.jl")
include("grpc_snapshots.jl")
include("grpc_service.jl")

# ============================================================================
# Exports
# ============================================================================

# Core
export QdrantConnection, set_client!, get_client, QdrantError

# Transport
export AbstractTransport, HTTPTransport, GRPCTransport, is_grpc

# gRPC utilities (for advanced users)
export to_proto_point, from_proto_scored_point, from_proto_retrieved_point
export julia_value_to_proto, proto_value_to_julia

# Type hierarchy
export AbstractQdrantType, AbstractConfig, AbstractRequest, AbstractCondition, AbstractResponse

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
export Point, NamedVector

# Conditions
export Filter, FieldCondition, MatchValue, MatchAny, MatchText,
       RangeCondition, HasIdCondition, IsEmptyCondition, IsNullCondition

# Request types
export QueryRequest

# Response types
export UpdateResponse, CountResponse, ScoredPoint, Record
export ScrollResponse, QueryResponse, GroupResult, GroupsResponse
export SnapshotInfo, CollectionDescription, AliasDescription
export HealthResponse, FacetHit, FacetResponse
export SearchMatrixPairsResponse, SearchMatrixOffsetsResponse

# Payload index types
export TextIndexParams

# Serialization
export serialize_body

# Collections API
export list_collections, create_collection, delete_collection,
       collection_exists, get_collection, update_collection,
       get_collection_optimizations,
       list_aliases, create_alias, delete_alias, rename_alias,
       list_collection_aliases

# Points API
export upsert_points, delete_points, get_points, get_point,
       set_payload, overwrite_payload,
       delete_payload, clear_payload, update_vectors, delete_vectors,
       scroll_points, count_points, batch_points

# Query API (modern unified)
export query_points, query_batch, query_groups

# Search matrix API
export search_matrix_pairs, search_matrix_offsets

# Facet API
export facet

# Snapshots API
export create_snapshot, list_snapshots, delete_snapshot,
       create_full_snapshot, list_full_snapshots, delete_full_snapshot

# Service API
export health_check, get_metrics, get_telemetry, get_version

# Payload index API
export create_payload_index, delete_payload_index

# Distributed API
export cluster_status

end # module
