"""
    QdrantClient

A high-performance, production-ready Julia client for the Qdrant vector database.

## Key Features
- Full Qdrant API coverage (Collections, Points, Search, Discovery, Snapshots, Distributed, Service)
- Type-safe API with StructUtils.jl for zero-cost JSON mapping
- Multiple dispatch design with explicit client support
- Connection pooling and automatic error handling
- Comprehensive error wrapping with QdrantError

## Usage

```julia
using QdrantClient

# Create a client
client = Client(host="http://localhost", port=6333)

# List collections
collections(client)

# Create a collection
create_collection(
    client,
    "my_collection",
    CreateCollection(
        vectors=VectorParams(size=128, distance="Cosine")
    )
)

# Search for vectors
search_points(
    client,
    "my_collection",
    SearchRequest(
        vector=rand(Float32, 128),
        limit=10
    )
)
```
"""
module QdrantClient

# Core dependencies
using HTTP
using JSON
using StructUtils

# Version info
const __VERSION__ = "0.1.0"

# ============================================================================
# Foundation: Error Handling
# ============================================================================
include("error.jl")

# ============================================================================
# Core: HTTP Client & Connection Management
# ============================================================================

"""
    Client <: Any

A Qdrant API client with connection pooling and authentication.

# Fields
- `host::String`: Server hostname (e.g., "http://localhost")
- `port::Int`: Server port (default: 6333)
- `api_key::Union{String, Nothing}`: Optional API key for authentication
- `pool::Union{HTTP.Pool, Nothing}`: Connection pool for performance
"""
Base.@kwdef mutable struct Client
    host::String = "http://localhost"
    port::Int = 6333
    api_key::Union{String, Nothing} = nothing
    pool::Union{HTTP.Pool, Nothing} = nothing
end

"""
    set_global_client(client::Client)::Client

Set the global default Qdrant client used by API functions.
"""
const GLOBAL_CLIENT = Ref{Client}()

function set_global_client(client::Client)::Client
    GLOBAL_CLIENT[] = client
    return client
end

"""
    get_global_client()::Client

Get the global default Qdrant client. Creates a default one if not set.
"""
function get_global_client()::Client
    if !isassigned(GLOBAL_CLIENT)
        GLOBAL_CLIENT[] = Client()
    end
    return GLOBAL_CLIENT[]
end

"""
    _get_pool(client::Client)::HTTP.Pool

Get or create the connection pool for a client.
"""
function _get_pool(client::Client)::HTTP.Pool
    if isnothing(client.pool)
        client.pool = HTTP.Pool()
    end
    return client.pool
end

"""
    _make_url(client::Client, path::String)::String

Construct a full URL from client host/port and path.
"""
function _make_url(client::Client, path::String)::String
    # Remove leading slash if present
    clean_path = startswith(path, "/") ? path[2:end] : path
    return "$(client.host):$(client.port)/$clean_path"
end

"""
    _make_headers(client::Client; kwargs...)::Dict{String, String}

Construct HTTP headers for a request, including authentication if available.
"""
function _make_headers(client::Client; kwargs...)::Dict{String, String}
    headers = Dict{String, String}(
        "Content-Type" => "application/json",
        "User-Agent" => "QdrantClient.jl/$__VERSION__"
    )

    if !isnothing(client.api_key)
        headers["api-key"] = client.api_key
    end

    merge!(headers, kwargs)
    return headers
end

"""
    _request(method::Function, client::Client, path::String, body=nothing;
              query=nothing, kwargs...)

Internal HTTP request wrapper with error handling and connection pooling.

Wraps all HTTP exceptions in QdrantError. Handles JSON serialization/deserialization.
"""
function _request(
    method::Function,
    client::Client,
    path::String,
    body=nothing;
    query=nothing,
    kwargs...
)
    try
        url = _make_url(client, path)
        headers = _make_headers(client)
        pool = _get_pool(client)

        # Prepare request arguments
        req_args = Dict{Symbol, Any}(
            :pool => pool,
            :headers => headers,
            :status_exception => false
        )

        # Add query parameters if provided
        if !isnothing(query)
            req_args[:query] = query
        end

        # Serialize body if provided
        request_body = nothing
        if !isnothing(body)
            # If body is a dict, serialize to JSON
            if isa(body, AbstractDict)
                request_body = JSON.json(body)
            elseif isa(body, String)
                request_body = body
            else
                # For other types, try JSON serialization directly
                try
                    request_body = JSON.json(body)
                catch
                    # If JSON serialization fails, convert to dict manually
                    dict_data = Dict()
                    for fname in fieldnames(typeof(body))
                        dict_data[fname] = getfield(body, fname)
                    end
                    request_body = JSON.json(dict_data)
                end
            end
            req_args[:body] = request_body
        end

        # Make the HTTP request
        response = method(url; req_args...)

        # Check for HTTP errors
        if response.status >= 400
            throw(api_error_response(response))
        end

        return response
    catch e
        if e isa QdrantError
            rethrow(e)
        elseif e isa HTTP.Exception
            throw(http_to_qdrant_error(e))
        else
            rethrow(e)
        end
    end
end

"""
    _struct_to_dict(obj::Any)::Dict

Convert a Julia struct to a dictionary, preserving field names and types.
"""
function _struct_to_dict(obj::Any)::Dict
    if isa(obj, AbstractDict)
        return obj
    end
    result = Dict()
    for fname in fieldnames(typeof(obj))
        val = getfield(obj, fname)
        if !isnothing(val)
            result[fname] = if val isa AbstractDict
                val
            elseif (val isa AbstractVector || val isa Tuple) && !(val isa AbstractString)
                _convert_collection(val)
            elseif isstructtype(typeof(val)) && !(val isa Number) && !(val isa AbstractString)
                _struct_to_dict(val)
            else
                val
            end
        end
    end
    return result
end

function _convert_collection(col::Union{Vector, NTuple})
    return [item isa AbstractDict ? item : (item isa Number || item isa AbstractString ? item : _struct_to_dict(item)) for item in col]
end

"""
    _parse_response(response::HTTP.Response, ::Type{T}) where T

Parse an HTTP response body into a Julia type T.
"""
function _parse_response(response::HTTP.Response, ::Type{T}) where T
    body_str = String(response.body)
    if isempty(body_str)
        return nothing
    end

    parsed = JSON.parse(body_str; dicttype=Dict{Symbol, Any})
    result = haskey(parsed, :result) ? parsed[:result] : parsed

    try
        return result
    catch
        return result
    end
end

# ============================================================================
# Type Definitions
# ============================================================================
include("types.jl")

# ============================================================================
# API Modules
# ============================================================================
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

# Core types and functions
export Client,
    set_global_client,
    get_global_client,
    QdrantError

# Error types
export QdrantError

# Type definitions
export QdrantResponse,
    CollectionDescription,
    CollectionsResponse,
    CollectionConfig,
    CollectionUpdate,
    CreateCollection,
    UpdateCollection,
    CollectionInfo,
    PointStruct,
    PointId,
    PointStructDense,
    PointStructSparse,
    PointStructMultiVector,
    PointStructNamedVectors,
    VectorParams,
    VectorParamsDiff,
    VectorParamsSparse,
    PointsSelector,
    PointIdsList,
    FilterSelector,
    AllVariants,
    Payload,
    Filter,
    FieldCondition,
    MatchValue,
    MatchFilter,
    MatchAnyFilter,
    MatchExceptFilter,
    RangeFilter,
    GeoBoundingBox,
    GeoRadius,
    GeoPolygon,
    GeoFilter,
    HasIdFilter,
    IsEmptyFilter,
    IsNullFilter,
    NestedFilter,
    SearchRequest,
    SearchResponse,
    ScoredPoint,
    RecommendRequest,
    RecommendResponse,
    RecommendedPoint,
    QueryRequest,
    QueryResponse,
    QueryPoint,
    DiscoverRequest,
    DiscoverResponse,
    DiscovereredPoint,
    CountRequest,
    CountResponse,
    ScrollRequest,
    ScrollResponse,
    UpsertOperation,
    DeleteOperation,
    SetPayloadOperation,
    DeletePayloadOperation,
    ClearPayloadOperation,
    UpdateVectorsOperation,
    DeleteVectorsOperation,
    UpdateStatusOperation,
    OperationStatus,
    BatchVectorStruct,
    Batch,
    SnapshotDescription,
    ClusterStatus,
    PeerInfo,
    ConsensusThreadStatus,
    TelemetryData,
    MetricsData

# Collections API
export collections,
    create_collection,
    delete_collection,
    collection_exists,
    get_collection_info,
    update_collection,
    list_aliases,
    create_alias,
    delete_alias,
    rename_alias,
    list_collection_aliases

# Points API
export upsert_points,
    delete_points,
    retrieve_points,
    batch_points,
    scroll_points,
    count_points,
    delete_payload,
    set_payload,
    clear_payload,
    update_vectors,
    delete_vectors

# Search API
export search_points,
    search_batch,
    search_with_groups,
    recommend_points,
    recommend_batch,
    recommend_with_groups,
    query_points,
    query_batch,
    query_with_groups

# Discovery API
export discover_points,
    discover_batch

# Snapshots API
export create_snapshot,
    list_snapshots,
    delete_snapshot,
    recover_snapshot

# Distributed API
export cluster_status,
    get_peer,
    recover_peer

# Service API
export health_check,
    get_metrics,
    get_telemetry

end # module QdrantClient
