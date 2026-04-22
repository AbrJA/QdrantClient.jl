# ============================================================================
# Type Aliases
# ============================================================================

"""
    Optional{T}

Alias for `Union{Nothing, T}`. Used throughout for optional fields.
"""
const Optional{T} = Union{Nothing, T}

"""
    PointId

A unique point identifier — integer or UUID.
Qdrant accepts `uint64` or `uuid` format strings.
"""
const PointId = Union{Int, UUID}

# ============================================================================
# Abstract Type Hierarchy
# ============================================================================

"""
    AbstractQdrantType

Root of the Qdrant type hierarchy. All Qdrant structs subtype this.
"""
abstract type AbstractQdrantType end

"""
    AbstractConfig <: AbstractQdrantType

Configuration types for creating/updating resources.
"""
abstract type AbstractConfig <: AbstractQdrantType end

"""
    AbstractRequest <: AbstractQdrantType

Request types for query endpoints.
"""
abstract type AbstractRequest <: AbstractQdrantType end

"""
    AbstractCondition <: AbstractQdrantType

Filter condition types.
"""
abstract type AbstractCondition <: AbstractQdrantType end

"""
    AbstractResponse <: AbstractQdrantType

Typed response types returned from API calls.
"""
abstract type AbstractResponse <: AbstractQdrantType end

# ============================================================================
# Distance Enum
# ============================================================================

"""
    Distance

Vector distance metric.

Values: `Cosine`, `Euclid`, `Dot`, `Manhattan`
"""
@enum Distance Cosine Euclid Dot Manhattan

StructUtils.lower(d::Distance) = string(d)

# ============================================================================
# HNSW Configuration
# ============================================================================

"""
    HnswConfig <: AbstractConfig

HNSW index configuration parameters.

# Fields
- `m`: Number of edges per node in the index graph
- `ef_construct`: Number of neighbours to consider during index building
- `full_scan_threshold`: Size (KB) below which full-scan is preferred
- `max_indexing_threads`: Parallel threads for background index building
- `on_disk`: Store HNSW index on disk (default: false)
- `payload_m`: Custom M param for payload-aware HNSW links
- `inline_storage`: Store vector copies within the HNSW index file
"""
StructUtils.@kwarg struct HnswConfig <: AbstractConfig
    m::Optional{Int} = nothing
    ef_construct::Optional{Int} = nothing
    full_scan_threshold::Optional{Int} = nothing
    max_indexing_threads::Optional{Int} = nothing
    on_disk::Optional{Bool} = nothing
    payload_m::Optional{Int} = nothing
    inline_storage::Optional{Bool} = nothing
end

# ============================================================================
# WAL Configuration
# ============================================================================

"""
    WalConfig <: AbstractConfig

Write-Ahead Log configuration.

# Fields
- `wal_capacity_mb`: Size of a single WAL segment in MB
- `wal_segments_ahead`: Number of WAL segments to create ahead
- `wal_retain_closed`: Number of closed WAL segments to retain
"""
StructUtils.@kwarg struct WalConfig <: AbstractConfig
    wal_capacity_mb::Optional{Int} = nothing
    wal_segments_ahead::Optional{Int} = nothing
    wal_retain_closed::Optional{Int} = nothing
end

# ============================================================================
# Optimizer Configuration
# ============================================================================

"""
    OptimizersConfig <: AbstractConfig

Segment optimizer configuration.

# Fields
- `deleted_threshold`: Minimal fraction of deleted vectors to trigger optimization
- `vacuum_min_vector_number`: Minimal vectors in a segment for optimization
- `default_segment_number`: Target number of segments
- `max_segment_size`: Max segment size in KB
- `memmap_threshold`: Max in-memory vectors per segment (KB)
- `indexing_threshold`: Max vectors for plain index (KB)
- `flush_interval_sec`: Minimum interval between forced flushes
- `max_optimization_threads`: Max threads for optimizations per shard
- `prevent_unoptimized`: Prevent creation of large unoptimized segments
"""
StructUtils.@kwarg struct OptimizersConfig <: AbstractConfig
    deleted_threshold::Optional{Float64} = nothing
    vacuum_min_vector_number::Optional{Int} = nothing
    default_segment_number::Optional{Int} = nothing
    max_segment_size::Optional{Int} = nothing
    memmap_threshold::Optional{Int} = nothing
    indexing_threshold::Optional{Int} = nothing
    flush_interval_sec::Optional{Int} = nothing
    max_optimization_threads::Optional{Int} = nothing
    prevent_unoptimized::Optional{Bool} = nothing
end

# ============================================================================
# Quantization Configuration
# ============================================================================

"""
    QuantizationSearchParams <: AbstractConfig

Parameters for quantization during search.
"""
StructUtils.@kwarg struct QuantizationSearchParams <: AbstractConfig
    ignore::Optional{Bool} = nothing
    rescore::Optional{Bool} = nothing
    oversampling::Optional{Float64} = nothing
end

"""
    ScalarQuantizationConfig <: AbstractConfig

Scalar quantization parameters.
"""
StructUtils.@kwarg struct ScalarQuantizationConfig <: AbstractConfig
    type::String = "int8"
    quantile::Optional{Float64} = nothing
    always_ram::Optional{Bool} = nothing
end

"""
    ProductQuantizationConfig <: AbstractConfig

Product quantization parameters.
"""
StructUtils.@kwarg struct ProductQuantizationConfig <: AbstractConfig
    compression::String
    always_ram::Optional{Bool} = nothing
end

"""
    BinaryQuantizationConfig <: AbstractConfig

Binary quantization parameters.
"""
StructUtils.@kwarg struct BinaryQuantizationConfig <: AbstractConfig
    always_ram::Optional{Bool} = nothing
end

"""
    ScalarQuantization <: AbstractConfig

Scalar quantization wrapper.
"""
StructUtils.@kwarg struct ScalarQuantization <: AbstractConfig
    scalar::ScalarQuantizationConfig
end

"""
    ProductQuantization <: AbstractConfig

Product quantization wrapper.
"""
StructUtils.@kwarg struct ProductQuantization <: AbstractConfig
    product::ProductQuantizationConfig
end

"""
    BinaryQuantization <: AbstractConfig

Binary quantization wrapper.
"""
StructUtils.@kwarg struct BinaryQuantization <: AbstractConfig
    binary::BinaryQuantizationConfig
end

"""
    QuantizationConfig

Union of all quantization configuration types.
"""
const QuantizationConfig = Union{ScalarQuantization, ProductQuantization, BinaryQuantization}

# ============================================================================
# Search Parameters
# ============================================================================

"""
    SearchParams <: AbstractConfig

Parameters controlling the search process.

# Fields
- `hnsw_ef`: Size of the beam in beam-search (larger = more accurate, slower)
- `exact`: If true, search without approximation (exact but slow)
- `quantization`: Quantization parameters for search
- `indexed_only`: Only search among indexed/small segments
"""
StructUtils.@kwarg struct SearchParams <: AbstractConfig
    hnsw_ef::Optional{Int} = nothing
    exact::Optional{Bool} = nothing
    quantization::Optional{QuantizationSearchParams} = nothing
    indexed_only::Optional{Bool} = nothing
end

# ============================================================================
# Vector Parameters
# ============================================================================

"""
    VectorParams <: AbstractConfig

Configuration for a vector field in a collection.

# Examples
```julia
VectorParams(size=128, distance=Cosine)
VectorParams(size=4, distance=Dot, on_disk=true)
VectorParams(size=4, distance=Euclid, hnsw_config=HnswConfig(m=32, ef_construct=200))
```
"""
StructUtils.@kwarg struct VectorParams <: AbstractConfig
    size::Int
    distance::Distance
    hnsw_config::Optional{HnswConfig} = nothing
    quantization_config::Optional{QuantizationConfig} = nothing
    on_disk::Optional{Bool} = nothing
    datatype::Optional{String} = nothing
end

"""
    SparseVectorParams <: AbstractConfig

Configuration for sparse vector fields.
"""
StructUtils.@kwarg struct SparseVectorParams <: AbstractConfig
    index::Optional{Dict{String,Any}} = nothing
end

# ============================================================================
# Named Vector
# ============================================================================

"""
    NamedVector <: AbstractQdrantType

A vector with an associated name, for collections with multiple named vectors.

# Examples
```julia
NamedVector(name="image", vector=Float32[1.0, 0.0, 0.0, 0.0])
```
"""
StructUtils.@kwarg struct NamedVector <: AbstractQdrantType
    name::String
    vector::Union{Vector{Float32}, Vector{Float64}}
end

# ============================================================================
# Collection Types
# ============================================================================

"""
    CollectionParamsDiff <: AbstractConfig

Mutable collection parameters (used in update operations).
"""
StructUtils.@kwarg struct CollectionParamsDiff <: AbstractConfig
    replication_factor::Optional{Int} = nothing
    write_consistency_factor::Optional{Int} = nothing
    read_fan_out_factor::Optional{Int} = nothing
    read_fan_out_delay_ms::Optional{Int} = nothing
    on_disk_payload::Optional{Bool} = nothing
end

"""
    CollectionConfig <: AbstractConfig

Configuration for creating a collection.

# Examples
```julia
CollectionConfig(vectors=VectorParams(size=128, distance=Cosine))
CollectionConfig(
    vectors=VectorParams(size=4, distance=Dot),
    hnsw_config=HnswConfig(m=32),
    optimizers_config=OptimizersConfig(indexing_threshold=10000),
)
# Named vectors:
CollectionConfig(vectors=Dict{String,VectorParams}(
    "image" => VectorParams(size=512, distance=Cosine),
    "text" => VectorParams(size=768, distance=Dot),
))
```
"""
StructUtils.@kwarg struct CollectionConfig <: AbstractConfig
    vectors::Union{VectorParams, Dict{String,VectorParams}}
    sparse_vectors::Optional{Dict{String,SparseVectorParams}} = nothing
    shard_number::Optional{Int} = nothing
    replication_factor::Optional{Int} = nothing
    write_consistency_factor::Optional{Int} = nothing
    on_disk_payload::Optional{Bool} = nothing
    hnsw_config::Optional{HnswConfig} = nothing
    wal_config::Optional{WalConfig} = nothing
    optimizers_config::Optional{OptimizersConfig} = nothing
    quantization_config::Optional{QuantizationConfig} = nothing
    sharding_method::Optional{String} = nothing
    init_from::Optional{Dict{String,Any}} = nothing
end

"""
    CollectionUpdate <: AbstractConfig

Patch payload for updating collection parameters.

# Examples
```julia
CollectionUpdate(optimizers_config=OptimizersConfig(indexing_threshold=10000))
CollectionUpdate(params=CollectionParamsDiff(replication_factor=2))
```
"""
StructUtils.@kwarg struct CollectionUpdate <: AbstractConfig
    optimizers_config::Optional{OptimizersConfig} = nothing
    params::Optional{CollectionParamsDiff} = nothing
    hnsw_config::Optional{HnswConfig} = nothing
    quantization_config::Optional{QuantizationConfig} = nothing
    vectors::Optional{Dict{String,Any}} = nothing
end

# ============================================================================
# Points
# ============================================================================

"""
    Point <: AbstractQdrantType

A point with id, vector(s), and optional payload.

# Examples
```julia
Point(id=1, vector=Float32[0.1, 0.2, 0.3, 0.4])
Point(id=uuid4(), vector=Float32[0.1, 0.2, 0.3, 0.4], payload=Dict("label" => "cat"))
Point(id=1, vector=NamedVector(name="image", vector=Float32[1.0, 0.0, 0.0, 0.0]))
Point(id=1, vector=Dict{String,Vector{Float32}}("image" => Float32[...], "text" => Float32[...]))
```
"""
StructUtils.@kwarg struct Point <: AbstractQdrantType
    id::PointId
    vector::Union{Vector{Float32}, Vector{Float64}, NamedVector, Dict{String,Vector{Float32}}, Dict{String,Vector{Float64}}}
    payload::Optional{Dict{String,Any}} = nothing
end

# ============================================================================
# Lookup Location
# ============================================================================

"""
    LookupLocation <: AbstractConfig

Location to look up vectors in a different collection.
"""
StructUtils.@kwarg struct LookupLocation <: AbstractConfig
    collection::String
    vector::Optional{String} = nothing
end

# ============================================================================
# Filters & Conditions
# ============================================================================

"""
    MatchValue <: AbstractCondition

Match a specific value.
"""
StructUtils.@kwarg struct MatchValue <: AbstractCondition
    value::Union{String, Int, Float64, Bool}
end

"""
    MatchAny <: AbstractCondition

Match any of the given values.
"""
StructUtils.@kwarg struct MatchAny <: AbstractCondition
    any::Vector{Any}
end

"""
    MatchText <: AbstractCondition

Full-text match.
"""
StructUtils.@kwarg struct MatchText <: AbstractCondition
    text::String
end

"""
    RangeCondition <: AbstractCondition

Range comparison filter.
"""
StructUtils.@kwarg struct RangeCondition <: AbstractCondition
    gte::Optional{Float64} = nothing
    gt::Optional{Float64} = nothing
    lte::Optional{Float64} = nothing
    lt::Optional{Float64} = nothing
end

"""
    FieldCondition <: AbstractCondition

Condition on a specific payload field.
"""
StructUtils.@kwarg struct FieldCondition <: AbstractCondition
    key::String
    range::Optional{RangeCondition} = nothing
    match::Optional{Union{MatchValue, MatchAny, MatchText}} = nothing
    geo_bounding_box::Optional{Dict{String,Any}} = nothing
    geo_radius::Optional{Dict{String,Any}} = nothing
    geo_polygon::Optional{Dict{String,Any}} = nothing
    values_count::Optional{Dict{String,Any}} = nothing
end

"""
    HasIdCondition <: AbstractCondition

Filter points by ID.
"""
StructUtils.@kwarg struct HasIdCondition <: AbstractCondition
    has_id::Vector{PointId}
end

"""
    IsEmptyCondition <: AbstractCondition

Filter for empty fields.
"""
StructUtils.@kwarg struct IsEmptyCondition <: AbstractCondition
    is_empty::Dict{String,Any}
end

"""
    IsNullCondition <: AbstractCondition

Filter for null fields.
"""
StructUtils.@kwarg struct IsNullCondition <: AbstractCondition
    is_null::Dict{String,Any}
end

"""
    Filter <: AbstractCondition

Compound filter with `must`, `should`, `must_not` clauses.

# Examples
```julia
Filter(must=[Dict("key" => "color", "match" => Dict("value" => "red"))])
```
"""
StructUtils.@kwarg struct Filter <: AbstractCondition
    must::Optional{Vector{Any}} = nothing
    should::Optional{Vector{Any}} = nothing
    must_not::Optional{Vector{Any}} = nothing
    min_should::Optional{Dict{String,Any}} = nothing
end

# ============================================================================
# Query Request (Universal API — replaces deprecated search/recommend/discover)
# ============================================================================

"""
    QueryRequest <: AbstractRequest

Advanced query request (Qdrant universal query API). Replaces the deprecated
`search_points`, `recommend_points`, and `discover_points` endpoints.

# Examples
```julia
# Nearest-neighbor search
QueryRequest(query=Float32[1,0,0,0], limit=5)

# With named vector
QueryRequest(query=Float32[1,0,0,0], limit=10, using_="image", with_payload=true)

# Recommendation via query API
QueryRequest(query=Dict("recommend" => Dict("positive" => [1], "negative" => [3])), limit=5)

# Prefetch + re-rank
QueryRequest(query=Float32[1,0,0,0], limit=5,
    prefetch=[Dict("query" => Float32[1,0,0,0], "limit" => 50)])
```
"""
StructUtils.@kwarg struct QueryRequest <: AbstractRequest
    query::Optional{Union{Vector{Float32}, Vector{Float64}, String, Dict{String,Any}}} = nothing
    limit::Optional{Int} = nothing
    filter::Optional{Filter} = nothing
    offset::Optional{Int} = nothing
    with_payload::Optional{Union{Bool, Vector{String}}} = nothing
    with_vector::Optional{Union{Bool, Vector{String}}} = nothing
    score_threshold::Optional{Float64} = nothing
    using_::Optional{String} = nothing &(name="using",)
    prefetch::Optional{Union{Dict{String,Any}, Vector{Any}}} = nothing
    params::Optional{SearchParams} = nothing
    lookup_from::Optional{LookupLocation} = nothing
    group_by::Optional{String} = nothing
    group_size::Optional{Int} = nothing
end

# ============================================================================
# Response Types — type-stable returns from API calls
# ============================================================================

"""
    UpdateResponse <: AbstractResponse

Result of a mutating operation (upsert, delete, set_payload, etc.).

# Fields
- `operation_id::Int`: Server-assigned operation ID
- `status::String`: Operation status (`"completed"` or `"acknowledged"`)
"""
struct UpdateResponse <: AbstractResponse
    operation_id::Int
    status::String
end

"""
    CountResponse <: AbstractResponse

Result of `count_points`.

# Fields
- `count::Int`: Number of matching points
"""
struct CountResponse <: AbstractResponse
    count::Int
end

"""
    ScoredPoint <: AbstractResponse

A point returned from a search/query, with a similarity score.

# Fields
- `id::PointId`: Point identifier
- `version::Int`: Point version
- `score::Float64`: Similarity score
- `payload::Optional{Dict{String,Any}}`: Payload data
- `vector::Any`: Vector data (Float32[], Dict, etc.)
"""
struct ScoredPoint <: AbstractResponse
    id::PointId
    version::Int
    score::Float64
    payload::Optional{Dict{String,Any}}
    vector::Any
end

"""
    Record <: AbstractResponse

A stored point record (from `get_points`, `scroll_points`).

# Fields
- `id::PointId`: Point identifier
- `payload::Optional{Dict{String,Any}}`: Payload data
- `vector::Any`: Vector data
"""
struct Record <: AbstractResponse
    id::PointId
    payload::Optional{Dict{String,Any}}
    vector::Any
end

"""
    ScrollResponse <: AbstractResponse

Result of `scroll_points`.

# Fields
- `points::Vector{Record}`: Page of records
- `next_page_offset::Optional{PointId}`: Offset for the next page (nothing if last page)
"""
struct ScrollResponse <: AbstractResponse
    points::Vector{Record}
    next_page_offset::Optional{PointId}
end

"""
    QueryResponse <: AbstractResponse

Result of `query_points`.

# Fields
- `points::Vector{ScoredPoint}`: Matching points with scores
"""
struct QueryResponse <: AbstractResponse
    points::Vector{ScoredPoint}
end

"""
    GroupResult <: AbstractResponse

A single group within a grouped query result.

# Fields
- `id::Any`: Group key value
- `hits::Vector{ScoredPoint}`: Points in this group
"""
struct GroupResult <: AbstractResponse
    id::Any
    hits::Vector{ScoredPoint}
end

"""
    GroupsResponse <: AbstractResponse

Result of `query_groups`.

# Fields
- `groups::Vector{GroupResult}`: Groups of matching points
"""
struct GroupsResponse <: AbstractResponse
    groups::Vector{GroupResult}
end

"""
    SnapshotInfo <: AbstractResponse

Description of a snapshot.

# Fields
- `name::String`: Snapshot filename
- `creation_time::Optional{String}`: ISO timestamp of creation
- `size::Int`: Snapshot size in bytes
- `checksum::Optional{String}`: Checksum if available
"""
struct SnapshotInfo <: AbstractResponse
    name::String
    creation_time::Optional{String}
    size::Int
    checksum::Optional{String}
end

"""
    CollectionDescription <: AbstractResponse

Brief collection info from `list_collections`.

# Fields
- `name::String`: Collection name
"""
struct CollectionDescription <: AbstractResponse
    name::String
end

"""
    AliasDescription <: AbstractResponse

Alias mapping from `list_aliases`.

# Fields
- `alias_name::String`
- `collection_name::String`
"""
struct AliasDescription <: AbstractResponse
    alias_name::String
    collection_name::String
end

"""
    HealthResponse <: AbstractResponse

Health check result.

# Fields
- `title::String`: Service title
- `version::String`: Server version
"""
struct HealthResponse <: AbstractResponse
    title::String
    version::String
end

"""
    FacetHit <: AbstractResponse

A single facet count.

# Fields
- `value::Any`: The facet value
- `count::Int`: Number of points with this value
"""
struct FacetHit <: AbstractResponse
    value::Any
    count::Int
end

"""
    FacetResponse <: AbstractResponse

Result of `facet`.

# Fields
- `hits::Vector{FacetHit}`: Facet value counts
"""
struct FacetResponse <: AbstractResponse
    hits::Vector{FacetHit}
end

"""
    SearchMatrixPairsResponse <: AbstractResponse

Distance matrix in pair format.

# Fields
- `pairs::Vector{Dict{String,Any}}`: Distance pairs
"""
struct SearchMatrixPairsResponse <: AbstractResponse
    pairs::Vector{Dict{String,Any}}
end

"""
    SearchMatrixOffsetsResponse <: AbstractResponse

Distance matrix in offset format.

# Fields
- `offsets_row::Vector{Int}`: Row offsets
- `offsets_col::Vector{Int}`: Column offsets
- `scores::Vector{Float64}`: Distance scores
- `ids::Vector{PointId}`: Point IDs
"""
struct SearchMatrixOffsetsResponse <: AbstractResponse
    offsets_row::Vector{Int}
    offsets_col::Vector{Int}
    scores::Vector{Float64}
    ids::Vector{PointId}
end

# ============================================================================
# Payload Index Types
# ============================================================================

"""
    TextIndexParams <: AbstractConfig

Configuration for full-text index on a payload field.

# Examples
```julia
TextIndexParams(tokenizer="word", lowercase=true)
```
"""
StructUtils.@kwarg struct TextIndexParams <: AbstractConfig
    type::String = "text"
    tokenizer::Optional{String} = nothing
    min_token_len::Optional{Int} = nothing
    max_token_len::Optional{Int} = nothing
    lowercase::Optional{Bool} = nothing
end
