# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

Supports both HTTP/REST and gRPC transports with typed responses for all endpoints.

## Installation

```julia
] add QdrantClient
```

Requires Julia 1.12+.

---

## Quick Start

```julia
using QdrantClient

# HTTP (default)
client = QdrantConnection()   # localhost:6333

# gRPC (~2-10× faster for bulk operations)
client = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# Create a collection
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
# => true

# Upsert points
resp = upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
]; wait=true)
# => UpdateResponse(operation_id=0, status="completed")

# Query (universal API — replaces search/recommend/discover)
results = query_points(client, "demo";
    query=Float32[1, 0, 0, 0], limit=2, with_payload=true)
# => QueryResponse with results.points::Vector{ScoredPoint}

# Cleanup
delete_collection(client, "demo")  # => true
```

---

## Connection

```@docs
QdrantConnection
HTTPTransport
GRPCTransport
AbstractTransport
set_client!
get_client
```

---

## Errors

```@docs
QdrantError
```

---

## Collections

```@docs
list_collections
create_collection
get_collection
collection_exists
update_collection
delete_collection
```

### Aliases

```@docs
list_aliases
list_collection_aliases
create_alias
rename_alias
delete_alias
```

---

## Points

```@docs
upsert_points
get_points
get_point
delete_points
```

### Payload

```@docs
set_payload
overwrite_payload
delete_payload
clear_payload
```

### Vectors

```@docs
update_vectors
delete_vectors
```

### Scroll & Count

```@docs
scroll_points
count_points
```

### Batch

```@docs
batch_points
```

### Payload Index

```@docs
create_payload_index
delete_payload_index
```

---

## Query (Universal API)

The `query_points` endpoint replaces the deprecated `search_points`, `recommend_points`,
and `discover_points` functions from v0.x.

```@docs
query_points
query_batch
query_groups
```

---

## Faceted Search

```@docs
facet
```

---

## Search Matrix

```@docs
search_matrix_pairs
search_matrix_offsets
```

---

## Snapshots

```@docs
create_snapshot
list_snapshots
delete_snapshot
create_full_snapshot
list_full_snapshots
delete_full_snapshot
```

---

## Cluster & Service

```@docs
cluster_status
health_check
get_version
get_metrics
get_telemetry
```

---

## Response Types

```@docs
UpdateResponse
QueryResponse
ScoredPoint
ScrollResponse
Record
CountResponse
GroupsResponse
GroupResult
SnapshotInfo
CollectionDescription
AliasDescription
HealthResponse
FacetResponse
FacetHit
```

---

## Types

### Core

```@docs
Optional
PointId
AbstractQdrantType
AbstractConfig
AbstractCondition
```

### Distance

```@docs
Distance
```

### Collection Configuration

```@docs
CollectionConfig
CollectionUpdate
VectorParams
SparseVectorParams
HnswConfig
WalConfig
OptimizersConfig
```

### Quantization

```@docs
ScalarQuantization
ProductQuantization
BinaryQuantization
```

### Points

```@docs
Point
NamedVector
LookupLocation
```

### Filters

```@docs
Filter
FieldCondition
MatchValue
MatchAny
MatchText
RangeCondition
HasIdCondition
IsEmptyCondition
IsNullCondition
```

### Requests

```@docs
QueryRequest
SearchParams
TextIndexParams
```

---

## gRPC Limitations

Due to Proto3 wire format constraints:

- **`create_payload_index` with `"keyword"` type** — Proto3 does not send the default enum value (`FieldType.FieldTypeKeyword = 0`) over the wire, so keyword indexes are silently created as integer indexes. Use HTTP transport for keyword indexes.
- **`get_point` (single point)** — Not available over gRPC; use `get_points(client, collection, [id])`.
- **Snapshot download** — gRPC snapshot operations create/list/delete but cannot download snapshot files.

---

## Architecture

QdrantClient.jl is organized around three principles:

**Flat, discoverable API.** Every operation is a top-level function — `query_points`,
`upsert_points`, `create_collection`. Functions are grouped by noun, not verb, so
`<TAB>` completion after `query_` shows everything related to queries.

**Explicit client or global default.** Every function accepts an optional leading
`QdrantConnection` argument. When omitted the global default (set via `set_client!`)
is used.

**Typed responses.** All endpoints return concrete Julia structs (`UpdateResponse`,
`QueryResponse`, `ScrollResponse`, etc.) for type-stable downstream code. No more
indexing into `Dict{String,Any}`.

### Module layout

| File | Contents |
|------|----------|
| `src/QdrantClient.jl` | Transport, connection, typed parsers, exports |
| `src/types.jl` | All struct definitions (request & response types) |
| `src/error.jl` | `QdrantError` |
| `src/collections.jl` | Collections & aliases API |
| `src/points.jl` | Points, payload, vectors, scroll, count, index |
| `src/query.jl` | Query, query batch, query groups, facet, search matrix |
| `src/snapshots.jl` | Snapshots |
| `src/distributed.jl` | Cluster status |
| `src/service.jl` | Health, metrics, telemetry |
| `src/grpc_transport.jl` | gRPC transport layer |
| `src/grpc_collections.jl` | gRPC collection operations |
| `src/grpc_points.jl` | gRPC point operations |
| `src/grpc_query.jl` | gRPC query operations |
| `src/grpc_snapshots.jl` | gRPC snapshot operations |
| `src/grpc_service.jl` | gRPC service operations |
