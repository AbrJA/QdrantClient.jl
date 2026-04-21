# ============================================================================
# Type Definitions for Qdrant API
# ============================================================================
# All types are defined using StructUtils for zero-cost JSON mapping.
# Field names and types match the OpenAPI specification exactly.

"""
    QdrantResponse{T}

Generic wrapper for Qdrant API responses.

# Fields
- `time::Float64`: Time spent processing (in seconds)
- `status::String`: Status string ("ok" for success)
- `result::Union{T, Nothing}`: The result data (type depends on endpoint)
"""
Base.@kwdef struct QdrantResponse{T}
    time::Float64
    status::String
    result::Union{T, Nothing} = nothing
end

# ============================================================================
# Collections
# ============================================================================

"""
    CollectionDescription

Description of a collection.
"""
Base.@kwdef struct CollectionDescription
    name::String
end

"""
    CollectionsResponse

Response for listing collections.
"""
Base.@kwdef struct CollectionsResponse
    collections::Vector{CollectionDescription}
end

"""
    VectorParams

Parameters for a vector field.
"""
Base.@kwdef struct VectorParams
    size::Int
    distance::String  # "Cosine", "Euclid", "Dot", "Manhattan"
    hnsw_config::Union{Nothing, Dict} = nothing
    quantization_config::Union{Nothing, Dict} = nothing
    on_disk::Union{Nothing, Bool} = nothing
end

"""
    VectorParamsDiff

Diff for updating vector parameters (all fields optional).
"""
Base.@kwdef struct VectorParamsDiff
    size::Union{Nothing, Int} = nothing
    distance::Union{Nothing, String} = nothing
    hnsw_config::Union{Nothing, Dict} = nothing
    quantization_config::Union{Nothing, Dict} = nothing
    on_disk::Union{Nothing, Bool} = nothing
end

"""
    VectorParamsSparse

Parameters for sparse vectors.
"""
Base.@kwdef struct VectorParamsSparse
    index::Bool
end

"""
    CollectionConfig

Configuration used when creating a collection.
"""
Base.@kwdef struct CollectionConfig
    vectors::Union{VectorParams, Dict}
    sparse_vectors::Union{Nothing, Dict} = nothing
    shard_number::Union{Nothing, Int} = nothing
    replication_factor::Union{Nothing, Int} = nothing
    write_consistency_factor::Union{Nothing, Int} = nothing
    on_disk_payload::Union{Nothing, Bool} = nothing
    hnsw_config::Union{Nothing, Dict} = nothing
    wal_config::Union{Nothing, Dict} = nothing
    optimizers_config::Union{Nothing, Dict} = nothing
    init_from::Union{Nothing, Dict} = nothing
end

const CreateCollection = CollectionConfig

"""
    CollectionUpdate

Patch payload used when updating a collection.
"""
Base.@kwdef struct CollectionUpdate
    optimizers_config::Union{Nothing, Dict} = nothing
    params::Union{Nothing, Dict} = nothing
end

const UpdateCollection = CollectionUpdate

"""
    CollectionInfo

Information about a collection.
"""
Base.@kwdef struct CollectionInfo
    name::String
    points_count::Int
    vectors_count::Union{Int, Dict}
    segments_count::Int
    status::String  # "green", "yellow", "red"
    config::Dict
    payload_schema::Union{Nothing, Dict} = nothing
    points_count_details::Union{Nothing, Dict} = nothing
end

# ============================================================================
# Points & Vectors
# ============================================================================

"""
    PointId

A unique point identifier (integer or UUID).
"""
const PointId = Union{Int, String}

"""
    PointStruct

A point with vector and optional payload.
"""
Base.@kwdef struct PointStruct
    id::PointId
    vector::Union{Vector{Float32}, Dict{String, Vector{Float32}}}
    payload::Union{Nothing, Dict} = nothing
end

"""
    PointStructDense

Dense vector point.
"""
Base.@kwdef struct PointStructDense
    id::PointId
    vector::Vector{Float32}
    payload::Union{Nothing, Dict} = nothing
end

"""
    PointStructSparse

Sparse vector point.
"""
Base.@kwdef struct PointStructSparse
    id::PointId
    vector::Dict  # {indices: Int[], values: Float32[]}
    payload::Union{Nothing, Dict} = nothing
end

"""
    PointStructMultiVector

Multi-vector point (multiple dense vectors).
"""
Base.@kwdef struct PointStructMultiVector
    id::PointId
    vector::Dict{String, Vector{Float32}}
    payload::Union{Nothing, Dict} = nothing
end

"""
    PointStructNamedVectors

Named vectors point.
"""
Base.@kwdef struct PointStructNamedVectors
    id::PointId
    vector::Dict{String, Union{Vector{Float32}, Dict}}
    payload::Union{Nothing, Dict} = nothing
end

"""
    PointsSelector

Selector for which points to update/delete.
"""
const PointsSelector = Union{
    NamedTuple{(:points,), Tuple{Vector{PointId}}},  # PointIdsList
    Dict{Symbol, Any}  # Filter
}

"""
    PointIdsList

Selector for specific points by ID.
"""
Base.@kwdef struct PointIdsList
    points::Vector{PointId}
end

"""
    FilterSelector

Filter conditions for point selection.
"""
Base.@kwdef struct FilterSelector
    filter::Dict
end

"""
    AllVariants

Match all points.
"""
struct AllVariants
end

"""
    Payload

Point payload data (arbitrary JSON).
"""
const Payload = Dict{String, Any}

# ============================================================================
# Filters
# ============================================================================

"""
    Filter

Filter conditions for searching/filtering points.
"""
Base.@kwdef struct Filter
    must::Union{Nothing, Vector{Dict}} = nothing
    should::Union{Nothing, Vector{Dict}} = nothing
    must_not::Union{Nothing, Vector{Dict}} = nothing
end

"""
    FieldCondition

Condition on a specific field.
"""
Base.@kwdef struct FieldCondition
    key::String
    range::Union{Nothing, Dict} = nothing
    match::Union{Nothing, Dict} = nothing
    geo_bounding_box::Union{Nothing, Dict} = nothing
    geo_radius::Union{Nothing, Dict} = nothing
    geo_polygon::Union{Nothing, Dict} = nothing
    values_count::Union{Nothing, Dict} = nothing
end

"""
    MatchValue

Match a specific value.
"""
Base.@kwdef struct MatchValue
    value::Union{String, Int, Float32, Bool}
end

"""
    MatchFilter

Match multiple values.
"""
Base.@kwdef struct MatchFilter
    any::Union{Nothing, Vector{Union{String, Int, Float32, Bool}}} = nothing
    except::Union{Nothing, Vector{Union{String, Int, Float32, Bool}}} = nothing
end

"""
    MatchAnyFilter

Match if value equals any in list.
"""
Base.@kwdef struct MatchAnyFilter
    any::Vector{Union{String, Int, Float32, Bool}}
end

"""
    MatchExceptFilter

Match unless value is in except list.
"""
Base.@kwdef struct MatchExceptFilter
    except::Vector{Union{String, Int, Float32, Bool}}
end

"""
    RangeFilter

Range comparison filter.
"""
Base.@kwdef struct RangeFilter
    gte::Union{Nothing, Float32} = nothing
    gt::Union{Nothing, Float32} = nothing
    lte::Union{Nothing, Float32} = nothing
    lt::Union{Nothing, Float32} = nothing
end

"""
    GeoBoundingBox

Geographic bounding box filter.
"""
Base.@kwdef struct GeoBoundingBox
    bottom_right::Dict  # {lat: Float, lon: Float}
    top_left::Dict     # {lat: Float, lon: Float}
end

"""
    GeoRadius

Geographic radius filter.
"""
Base.@kwdef struct GeoRadius
    center::Dict  # {lat: Float, lon: Float}
    radius_meters::Float32
end

"""
    GeoPolygon

Geographic polygon filter.
"""
Base.@kwdef struct GeoPolygon
    exterior::Vector{Dict}  # [{lat: Float, lon: Float}, ...]
    interiors::Union{Nothing, Vector{Vector{Dict}}} = nothing
end

"""
    GeoFilter

Geographic filter (one of bounding box, radius, or polygon).
"""
Base.@kwdef struct GeoFilter
    geo_bounding_box::Union{Nothing, GeoBoundingBox} = nothing
    geo_radius::Union{Nothing, GeoRadius} = nothing
    geo_polygon::Union{Nothing, GeoPolygon} = nothing
end

"""
    HasIdFilter

Filter points with specific IDs.
"""
Base.@kwdef struct HasIdFilter
    has_id::Vector{PointId}
end

"""
    IsEmptyFilter

Filter empty fields.
"""
Base.@kwdef struct IsEmptyFilter
    is_empty::Dict  # {key: String}
end

"""
    IsNullFilter

Filter null fields.
"""
Base.@kwdef struct IsNullFilter
    is_null::Dict  # {key: String}
end

"""
    NestedFilter

Nested object filter.
"""
Base.@kwdef struct NestedFilter
    nested::Dict  # {key: String, filter: Filter}
end

# ============================================================================
# Search, Recommend, Query, Discover
# ============================================================================

"""
    SearchRequest

Request for searching similar vectors.
"""
Base.@kwdef struct SearchRequest
    vector::Union{Vector{Float32}, String, Dict}  # vector name for sparse
    filter::Union{Nothing, Filter} = nothing
    limit::Int
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
    vector_name::Union{Nothing, String} = nothing
    lookup_from::Union{Nothing, Dict} = nothing
    search_params::Union{Nothing, Dict} = nothing
end

"""
    ScoredPoint

A point with its search score.
"""
Base.@kwdef struct ScoredPoint
    id::PointId
    score::Float32
    version::Union{Nothing, Int} = nothing
    payload::Union{Nothing, Dict} = nothing
    vector::Union{Nothing, Vector{Float32}, Dict{String, Vector{Float32}}} = nothing
end

"""
    SearchResponse

Response from search endpoint.
"""
Base.@kwdef struct SearchResponse
    points::Vector{ScoredPoint}
end

"""
    RecommendRequest

Request for recommendation.
"""
Base.@kwdef struct RecommendRequest
    positive::Union{Nothing, Vector{PointId}} = nothing
    negative::Union{Nothing, Vector{PointId}} = nothing
    filter::Union{Nothing, Filter} = nothing
    limit::Int
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
    vector_name::Union{Nothing, String} = nothing
    lookup_from::Union{Nothing, Dict} = nothing
    search_params::Union{Nothing, Dict} = nothing
end

"""
    RecommendedPoint

A recommended point with score.
"""
Base.@kwdef struct RecommendedPoint
    id::PointId
    score::Union{Nothing, Float32} = nothing
    version::Union{Nothing, Int} = nothing
    payload::Union{Nothing, Dict} = nothing
    vector::Union{Nothing, Vector{Float32}, Dict{String, Vector{Float32}}} = nothing
end

"""
    RecommendResponse

Response from recommend endpoint.
"""
Base.@kwdef struct RecommendResponse
    points::Vector{RecommendedPoint}
end

"""
    QueryRequest

Advanced query request.
"""
Base.@kwdef struct QueryRequest
    query::Union{Vector{Float32}, String, Dict}  # vector or query object
    filter::Union{Nothing, Filter} = nothing
    limit::Int
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
    score_threshold::Union{Nothing, Float32} = nothing
end

"""
    QueryPoint

A point returned from query.
"""
Base.@kwdef struct QueryPoint
    id::PointId
    score::Union{Nothing, Float32} = nothing
    version::Union{Nothing, Int} = nothing
    payload::Union{Nothing, Dict} = nothing
    vector::Union{Nothing, Vector{Float32}, Dict{String, Vector{Float32}}} = nothing
end

"""
    QueryResponse

Response from query endpoint.
"""
Base.@kwdef struct QueryResponse
    points::Vector{QueryPoint}
end

"""
    DiscoverRequest

Discovery request (find points similar to target point).
"""
Base.@kwdef struct DiscoverRequest
    target::Union{PointId, Vector{Float32}, Dict}
    context::Union{Nothing, Vector{Dict}} = nothing  # [{positive: PointId, negative: PointId}]
    filter::Union{Nothing, Filter} = nothing
    limit::Int
    offset::Union{Nothing, Int} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
end

"""
    DiscoveredPoint

A discovered point.
"""
Base.@kwdef struct DiscoveredPoint
    id::PointId
    score::Union{Nothing, Float32} = nothing
    version::Union{Nothing, Int} = nothing
    payload::Union{Nothing, Dict} = nothing
    vector::Union{Nothing, Vector{Float32}, Dict{String, Vector{Float32}}} = nothing
end

"""
    DiscoverResponse

Response from discover endpoint.
"""
Base.@kwdef struct DiscoverResponse
    points::Vector{DiscoveredPoint}
end

# ============================================================================
# Count, Scroll
# ============================================================================

"""
    CountRequest

Request for counting points.
"""
Base.@kwdef struct CountRequest
    filter::Union{Nothing, Filter} = nothing
    exact::Union{Nothing, Bool} = nothing
end

"""
    CountResponse

Response from count endpoint.
"""
Base.@kwdef struct CountResponse
    count::Int
end

"""
    ScrollRequest

Request for scrolling through points.
"""
Base.@kwdef struct ScrollRequest
    filter::Union{Nothing, Filter} = nothing
    limit::Union{Nothing, Int} = nothing
    offset::Union{Nothing, String} = nothing
    with_payload::Union{Nothing, Bool, Vector{String}} = nothing
    with_vector::Union{Nothing, Bool, Vector{String}} = nothing
end

"""
    ScrollResponse

Response from scroll endpoint.
"""
Base.@kwdef struct ScrollResponse
    points::Vector{PointStruct}
    next_page_offset::Union{Nothing, String} = nothing
end

# ============================================================================
# Batch Operations
# ============================================================================

"""
    UpsertOperation

Upsert (insert or update) points.
"""
Base.@kwdef struct UpsertOperation
    upsert::Dict  # {points: PointStruct[], ordering: String}
end

"""
    DeleteOperation

Delete points.
"""
Base.@kwdef struct DeleteOperation
    delete::Dict  # {points: PointId[]} or {filter: Filter}
end

"""
    SetPayloadOperation

Set payload for points.
"""
Base.@kwdef struct SetPayloadOperation
    set_payload::Dict  # {payload: Dict, points: PointId[]} or {..., filter: Filter}
end

"""
    DeletePayloadOperation

Delete payload fields from points.
"""
Base.@kwdef struct DeletePayloadOperation
    delete_payload::Dict  # {keys: String[], points: PointId[]} or {..., filter: Filter}
end

"""
    ClearPayloadOperation

Clear all payload from points.
"""
Base.@kwdef struct ClearPayloadOperation
    clear_payload::Dict  # {points: PointId[]} or {filter: Filter}
end

"""
    UpdateVectorsOperation

Update vectors for points.
"""
Base.@kwdef struct UpdateVectorsOperation
    update_vectors::Dict  # {points: PointStruct[], filter?: Filter}
end

"""
    DeleteVectorsOperation

Delete vectors from points.
"""
Base.@kwdef struct DeleteVectorsOperation
    delete_vectors::Dict  # {vector_names: String[], points: PointId[]} or {..., filter: Filter}
end

"""
    UpdateStatusOperation

Update operation status.
"""
Base.@kwdef struct UpdateStatusOperation
    status::String
end

"""
    OperationStatus

Status of a batch operation.
"""
Base.@kwdef struct OperationStatus
    operation_id::Int
    status::String  # "acknowledged", "completed", "failed"
    error::Union{Nothing, String} = nothing
end

"""
    BatchVectorStruct

Batch vector for multi-vector operations.
"""
Base.@kwdef struct BatchVectorStruct
    ids::Vector{PointId}
    vectors::Vector{Union{Vector{Float32}, Dict{String, Vector{Float32}}}}
    payloads::Union{Nothing, Vector{Dict}} = nothing
end

"""
    Batch

Batch request for multiple operations.
"""
Base.@kwdef struct Batch
    operations::Vector{Dict}
end

# ============================================================================
# Snapshots
# ============================================================================

"""
    SnapshotDescription

Description of a snapshot.
"""
Base.@kwdef struct SnapshotDescription
    name::String
    creation_time::Union{Nothing, String} = nothing
    size::Union{Nothing, Int} = nothing
    checksum::Union{Nothing, String} = nothing
end

# ============================================================================
# Distributed & Cluster
# ============================================================================

"""
    ClusterStatus

Status of the cluster.
"""
Base.@kwdef struct ClusterStatus
    status::String  # "enabled", "disabled"
    peers::Union{Dict, Vector}
    peer_id::Union{Nothing, Int} = nothing
    consensus::Union{Nothing, Dict} = nothing
end

"""
    PeerInfo

Information about a cluster peer.
"""
Base.@kwdef struct PeerInfo
    peer_id::Int
    uri::String
    state::String  # "active", "inactive"
end

"""
    ConsensusThreadStatus

Status of consensus thread.
"""
Base.@kwdef struct ConsensusThreadStatus
    term::Int
    voted_for::Union{Nothing, Int} = nothing
    log_size::Union{Nothing, Int} = nothing
end

# ============================================================================
# Service (Health, Metrics, Telemetry)
# ============================================================================

"""
    TelemetryData

Telemetry information.
"""
Base.@kwdef struct TelemetryData
    version::String
end

"""
    MetricsData

Metrics information.
"""
Base.@kwdef struct MetricsData
    data::Union{String, Dict}
end
