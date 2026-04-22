# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database with HTTP/REST and gRPC support.

## Getting Started

```julia
using QdrantClient

conn = QdrantConnection()
create_collection(conn, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

upsert_points(conn, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
]; wait=true)

resp = query_points(conn, "demo"; query=Float32[1, 0, 0, 0], limit=5, with_payload=true)
resp.result.points   # Vector{ScoredPoint}
```

Every API call returns [`QdrantResponse{T}`](@ref) with `.result`, `.status`, and `.time`.

## API

```@docs
QdrantConnection
QdrantResponse
QdrantError
set_client!
get_client
```

### Collections

```@docs
list_collections
create_collection
delete_collection
collection_exists
get_collection
update_collection
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
```

### Service

```@docs
health_check
get_version
get_metrics
get_telemetry
cluster_status
```

### Payload Indexes

```@docs
create_payload_index
delete_payload_index
```

## Types

```@docs
CollectionConfig
VectorParams
HnswConfig
OptimizersConfig
SearchParams
Point
Filter
FieldCondition
QueryRequest
UpdateResult
CountResult
ScoredPoint
Record
ScrollResult
QueryResult
SnapshotInfo
HealthInfo
```
