# Qdrant.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database with HTTP/REST and gRPC support.

## Getting Started

```julia
using Qdrant

client = QdrantClient()
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
]; wait=true)

resp = query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=5, with_payload=true)
resp.result.points   # Vector{ScoredPoint}
```

Every API call returns [`QdrantResponse{T}`](@ref) with `.result`, `.status`, and `.time`.

## API

```@docs
Qdrant
QdrantClient
AbstractTransport
HTTPTransport
GRPCTransport
QdrantResponse
QdrantError
set_client!
get_client
serialize_body
```

### Type Hierarchy

```@docs
AbstractQdrantType
AbstractConfig
AbstractCondition
AbstractResponse
Optional
PointId
Distance
```

### Collections

```@docs
list_collections
create_collection
delete_collection
collection_exists
get_collection
update_collection
get_collection_optimizations
```

### Aliases

```@docs
create_alias
delete_alias
rename_alias
list_aliases
list_collection_aliases
```

### Points

```@docs
upsert_points
get_points
get_point
delete_points
scroll_points
count_points
batch_points
set_payload
overwrite_payload
delete_payload
clear_payload
update_vectors
delete_vectors
```

### Query

```@docs
query_points
query_batch
query_groups
search_matrix_pairs
search_matrix_offsets
facet
```

### Snapshots

```@docs
create_snapshot
list_snapshots
delete_snapshot
create_full_snapshot
list_full_snapshots
delete_full_snapshot
recover_from_snapshot
```

### Service

```@docs
health_check
get_version
get_metrics
get_telemetry
healthz
livez
readyz
get_issues
clear_issues
```

### Cluster & Distributed

```@docs
cluster_status
cluster_telemetry
recover_current_peer
remove_peer
collection_cluster_info
update_collection_cluster
```

### Shard Keys

```@docs
list_shard_keys
create_shard_key
delete_shard_key
```

### Shard Snapshots

```@docs
create_shard_snapshot
list_shard_snapshots
delete_shard_snapshot
```

### Payload Indexes

```@docs
create_payload_index
delete_payload_index
```

## Types

```@docs
CollectionConfig
CollectionUpdate
VectorParams
SparseVectorParams
HnswConfig
WalConfig
OptimizersConfig
CollectionParamsDiff
SearchParams
QuantizationSearchParams
ScalarQuantization
ScalarQuantizationConfig
ProductQuantization
ProductQuantizationConfig
BinaryQuantization
BinaryQuantizationConfig
QuantizationConfig
LookupLocation
TextIndexParams
Point
NamedVector
Filter
FieldCondition
MatchValue
MatchAny
MatchText
RangeCondition
HasIdCondition
IsEmptyCondition
IsNullCondition
QueryRequest
UpdateResult
CountResult
ScoredPoint
Record
ScrollResult
QueryResult
GroupResult
GroupsResult
SnapshotInfo
HealthInfo
CollectionDescription
AliasDescription
CollectionInfo
OptimizationsStatus
ClusterStatus
LocalShardInfo
RemoteShardInfo
ShardTransferInfo
CollectionClusterInfo
ShardKeysResult
FacetHit
FacetResult
SearchMatrixPairsResponse
SearchMatrixOffsetsResponse
```

## Advanced

```@docs
to_proto_point
from_proto_scored_point
from_proto_retrieved_point
julia_value_to_proto
proto_value_to_julia
```
