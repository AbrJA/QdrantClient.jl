"""
    QdrantClient

A Julian client for the [Qdrant](https://qdrant.tech) vector database.

Supports both HTTP/REST and gRPC transports. Every endpoint returns a
`QdrantResponse{T}` carrying the typed `.result`, the server `.status`,
and the server-side `.time`.

# Quick Start — HTTP (default)
```julia
using QdrantClient

conn = QdrantConnection()
create_collection(conn, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
upsert_points(conn, "demo", [Point(id=1, vector=Float32[1,0,0,0])])
resp = query_points(conn, "demo"; query=Float32[1,0,0,0], limit=5)
resp.result.points   # Vector{ScoredPoint}
```

# Quick Start — gRPC
```julia
conn = QdrantConnection(GRPCTransport(host="localhost", port=6334))
# Same API — transport is selected via dispatch
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

Base type for transport backends. Subtype to add new protocols.
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
    host::String = "localhost",
    port::Int    = 6333,
    api_key::Optional{String} = nothing,
    timeout::Int = 30,
    tls::Bool    = false,
)
    HTTPTransport(host, port, api_key, timeout, tls, nothing)
end

function ensure_pool!(t::HTTPTransport)
    t.pool === nothing && (t.pool = HTTP.Pool())
    t.pool
end

base_url(t::HTTPTransport) = "$(t.tls ? "https" : "http")://$(t.host):$(t.port)"

function transport_headers(t::HTTPTransport)
    headers = Pair{String,String}[
        "Content-Type" => "application/json",
        "User-Agent"   => "QdrantClient.jl/$CLIENT_VERSION",
    ]
    t.api_key !== nothing && push!(headers, "api-key" => t.api_key)
    headers
end

function transport_url(t::HTTPTransport, path::AbstractString)
    p = startswith(path, '/') ? path[2:end] : path
    "$(base_url(t))/$p"
end

# ============================================================================
# QdrantConnection{T} — parametric on transport for dispatch
# ============================================================================

"""
    QdrantConnection{T<:AbstractTransport}

Connection to a Qdrant server.  The type parameter `T` selects the transport,
enabling zero-cost dispatch to HTTP or gRPC code paths.

# Constructors
```julia
QdrantConnection()                                        # HTTP localhost:6333
QdrantConnection(host="myhost", port=6333, api_key="k")  # HTTP with options
QdrantConnection(GRPCTransport(host="h", port=6334))      # gRPC
```
"""
struct QdrantConnection{T<:AbstractTransport}
    transport::T
end

function QdrantConnection(;
    host::String = "localhost",
    port::Int    = 6333,
    api_key::Optional{String} = nothing,
    timeout::Int = 30,
    tls::Bool    = false,
)
    QdrantConnection(HTTPTransport(; host, port, api_key, timeout, tls))
end

const _GLOBAL_CLIENT = Ref{QdrantConnection}()

"""
    set_client!(conn) -> QdrantConnection

Set the global default connection.
"""
function set_client!(conn::QdrantConnection)
    _GLOBAL_CLIENT[] = conn
    conn
end

"""
    get_client() -> QdrantConnection

Return the global default connection, creating one if needed.
"""
function get_client()
    isassigned(_GLOBAL_CLIENT) ? _GLOBAL_CLIENT[] : (_GLOBAL_CLIENT[] = QdrantConnection())
end

# ============================================================================
# Serialization
# ============================================================================

const _JSON_KW = (omit_null=true, omit_empty=true)

"""
    serialize_body(x) -> String

Serialize to JSON, stripping `nothing` fields and empty collections.
"""
serialize_body(x) = JSON.json(x; _JSON_KW...)

# ============================================================================
# HTTP request infrastructure
# ============================================================================

function _parse_error(resp::HTTP.Response)
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
    http_request(method, conn, path, [body]; query=nothing) -> HTTP.Response

Low-level HTTP request with error handling and connection pooling.
"""
function http_request(method::Function, conn::QdrantConnection{HTTPTransport},
                      path::AbstractString, body=nothing; query=nothing)
    t = conn.transport
    url = transport_url(t, path)
    kw = Dict{Symbol,Any}(
        :pool             => ensure_pool!(t),
        :headers          => transport_headers(t),
        :status_exception => false,
    )
    query !== nothing && (kw[:query] = query)
    if body !== nothing
        kw[:body] = body isa AbstractString ? body : serialize_body(body)
    end
    resp = method(url; kw...)
    resp.status >= 400 && throw(_parse_error(resp))
    resp
end

# ============================================================================
# Response parsing — extract Qdrant {result, status, time} envelope
# ============================================================================

"""
    _unwrap(resp) -> (result, status, time)

Parse a Qdrant JSON response, returning `(result, status_string, time_float)`.
"""
function _unwrap(resp::HTTP.Response)
    b = String(resp.body)
    isempty(b) && return (nothing, "ok", 0.0)
    parsed = JSON.parse(b)
    result = get(parsed, "result", parsed)
    status = let s = get(parsed, "status", "ok")
        s isa AbstractDict ? get(s, "error", "ok") : string(s)
    end
    time = Float64(get(parsed, "time", 0.0))
    (result, String(status), time)
end

# ── Typed builders ───────────────────────────────────────────────────────

function _to_update_result(raw)::UpdateResult
    raw === true  && return UpdateResult(0, "completed")
    raw isa AbstractDict || return UpdateResult(0, "completed")
    UpdateResult(
        Int(get(raw, "operation_id", 0)),
        String(get(raw, "status", "completed")),
    )
end

function _to_record(d::AbstractDict)::Record
    id = d["id"]
    pid = id isa Integer ? Int(id) : UUID(string(id))
    Record(pid, get(d, "payload", nothing), get(d, "vector", nothing))
end

function _to_scored(d::AbstractDict)::ScoredPoint
    id = d["id"]
    pid = id isa Integer ? Int(id) : UUID(string(id))
    ScoredPoint(
        pid,
        Int(get(d, "version", 0)),
        Float64(get(d, "score", 0.0)),
        get(d, "payload", nothing),
        get(d, "vector", nothing),
    )
end

function _to_point_id(v)::PointId
    v isa Integer ? Int(v) : UUID(string(v))
end

# ── High-level response constructors ─────────────────────────────────────

function parse_update(resp::HTTP.Response)::QdrantResponse{UpdateResult}
    raw, status, time = _unwrap(resp)
    QdrantResponse(_to_update_result(raw), status, time)
end

function parse_bool(resp::HTTP.Response)::QdrantResponse{Bool}
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw === true, status, time)
end

function parse_records(resp::HTTP.Response)::QdrantResponse{Vector{Record}}
    raw, status, time = _unwrap(resp)
    records = raw isa AbstractVector ? Record[_to_record(p) for p in raw] : Record[]
    QdrantResponse(records, status, time)
end

function parse_query(resp::HTTP.Response)::QdrantResponse{QueryResult}
    raw, status, time = _unwrap(resp)
    points = if raw isa AbstractDict && haskey(raw, "points")
        ScoredPoint[_to_scored(p) for p in raw["points"]]
    elseif raw isa AbstractVector
        ScoredPoint[_to_scored(p) for p in raw]
    else
        ScoredPoint[]
    end
    QdrantResponse(QueryResult(points), status, time)
end

function parse_scroll(resp::HTTP.Response)::QdrantResponse{ScrollResult}
    raw, status, time = _unwrap(resp)
    if raw isa AbstractDict
        pts = haskey(raw, "points") ? Record[_to_record(p) for p in raw["points"]] : Record[]
        npo_raw = get(raw, "next_page_offset", nothing)
        npo = npo_raw === nothing ? nothing : _to_point_id(npo_raw)
        QdrantResponse(ScrollResult(pts, npo), status, time)
    else
        QdrantResponse(ScrollResult(Record[], nothing), status, time)
    end
end

function parse_count(resp::HTTP.Response)::QdrantResponse{CountResult}
    raw, status, time = _unwrap(resp)
    count = raw isa AbstractDict ? Int(get(raw, "count", 0)) : 0
    QdrantResponse(CountResult(count), status, time)
end

function parse_groups(resp::HTTP.Response)::QdrantResponse{GroupsResult}
    raw, status, time = _unwrap(resp)
    groups = GroupResult[]
    if raw isa AbstractDict
        for g in get(raw, "groups", Any[])
            gid = get(g, "id", nothing)
            hits_raw = get(g, "hits", Any[])
            hits = ScoredPoint[_to_scored(p) for p in hits_raw]
            push!(groups, GroupResult(gid, hits))
        end
    end
    QdrantResponse(GroupsResult(groups), status, time)
end

function parse_snapshot(resp::HTTP.Response)::QdrantResponse{SnapshotInfo}
    raw, status, time = _unwrap(resp)
    info = if raw isa AbstractDict
        SnapshotInfo(
            String(get(raw, "name", "")),
            get(raw, "creation_time", nothing),
            Int(get(raw, "size", 0)),
            get(raw, "checksum", nothing),
        )
    else
        SnapshotInfo("", nothing, 0, nothing)
    end
    QdrantResponse(info, status, time)
end

function parse_snapshot_list(resp::HTTP.Response)::QdrantResponse{Vector{SnapshotInfo}}
    raw, status, time = _unwrap(resp)
    list = if raw isa AbstractVector
        SnapshotInfo[SnapshotInfo(
            String(get(s, "name", "")),
            get(s, "creation_time", nothing),
            Int(get(s, "size", 0)),
            get(s, "checksum", nothing),
        ) for s in raw]
    else
        SnapshotInfo[]
    end
    QdrantResponse(list, status, time)
end

function parse_facet(resp::HTTP.Response)::QdrantResponse{FacetResult}
    raw, status, time = _unwrap(resp)
    hits = if raw isa AbstractDict
        FacetHit[FacetHit(get(h, "value", nothing), Int(get(h, "count", 0)))
                 for h in get(raw, "hits", Any[])]
    else
        FacetHit[]
    end
    QdrantResponse(FacetResult(hits), status, time)
end

# ── gRPC transport (defines GRPCTransport before API files) ──────────────
include("grpc_transport.jl")

# ── API files — HTTP implementations ────────────────────────────────────
include("collections.jl")
include("points.jl")
include("query.jl")
include("snapshots.jl")
include("distributed.jl")
include("service.jl")

# ── API files — gRPC implementations ────────────────────────────────────
include("grpc_collections.jl")
include("grpc_points.jl")
include("grpc_query.jl")
include("grpc_snapshots.jl")
include("grpc_service.jl")

# ============================================================================
# Exports
# ============================================================================

# Core
export QdrantConnection, QdrantResponse, set_client!, get_client, QdrantError

# Transport
export AbstractTransport, HTTPTransport, GRPCTransport

# Type hierarchy
export AbstractQdrantType, AbstractConfig, AbstractCondition, AbstractResponse

# Aliases
export Optional, PointId

# Distance
export Distance, Cosine, Euclid, Dot, Manhattan

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

# Response / result types
export UpdateResult, CountResult, ScoredPoint, Record
export ScrollResult, QueryResult, GroupResult, GroupsResult
export SnapshotInfo, CollectionDescription, AliasDescription
export HealthInfo, FacetHit, FacetResult
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

# Query API
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

# gRPC utilities (advanced)
export to_proto_point, from_proto_scored_point, from_proto_retrieved_point
export julia_value_to_proto, proto_value_to_julia

end # module
