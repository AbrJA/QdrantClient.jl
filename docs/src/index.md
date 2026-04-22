# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

## Installation

```julia
] add QdrantClient
```

Requires Julia 1.12+.

---

## Quick Start

```julia
using QdrantClient

client = QdrantConnection()   # localhost:6333
# or
client = QdrantConnection(host="qdrant.example.com", port=6333,
                          api_key="secret", tls=true)
# or set a global default
set_client!(QdrantConnection())

# Create a collection
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

# Upsert points
upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
    Point(id=3, vector=Float32[0, 0, 1, 0], payload=Dict("color" => "green")),
]; wait=true)

# Search
hits = search_points(client, "demo",
    SearchRequest(vector=Float32[1, 0, 0, 0], limit=2, with_payload=true))

# Universal query
results = query_points(client, "demo",
    QueryRequest(query=Float32[1, 0, 0, 0], limit=2))

# Cleanup
delete_collection(client, "demo")
```

---

## Connection

```@docs
QdrantConnection
HTTPTransport
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
delete_points
```

### Payload

```@docs
set_payload
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

## Search

```@docs
search_points
search_batch
search_groups
```

---

## Recommendations

```@docs
recommend_points
recommend_batch
recommend_groups
```

---

## Query (Universal API)

```@docs
query_points
query_batch
query_groups
```

---

## Discovery

```@docs
discover_points
discover_batch
```

---

## Snapshots

```@docs
create_snapshot
list_snapshots
delete_snapshot
```

---

## Cluster & Service

```@docs
cluster_status
health_check
get_metrics
get_telemetry
```

---

## Types

### Core

```@docs
Optional
PointId
AbstractQdrantType
AbstractConfig
AbstractRequest
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
CollectionParamsDiff
VectorParams
SparseVectorParams
HnswConfig
WalConfig
OptimizersConfig
```

### Quantization

```@docs
ScalarQuantization
ScalarQuantizationConfig
ProductQuantization
ProductQuantizationConfig
BinaryQuantization
BinaryQuantizationConfig
QuantizationSearchParams
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
SearchRequest
SearchParams
RecommendRequest
QueryRequest
DiscoverRequest
TextIndexParams
```

---

## Serialization

```@docs
serialize_body
```

---

## Architecture

QdrantClient.jl is organized around three principles:

**Flat, discoverable API.** Every operation is a top-level function — `search_points`,
`upsert_points`, `create_collection`. Functions are grouped by noun, not verb, so
`<TAB>` completion after `search_` shows everything related to search.

**Explicit client or global default.** Every function accepts an optional leading
`QdrantConnection` argument. When omitted the global default (set via `set_client!`)
is used. This means you can write scripts with a single `set_client!` call and never
pass the client again, or pass it explicitly in multi-tenant code.

**Zero-cost JSON mapping.** Structs are annotated with `StructUtils.@kwarg` and
serialized by `JSON.json(x; omit_null=true, omit_empty=true)`. `nothing` fields and
empty collections are stripped automatically, so the wire format stays clean without
manual `to_dict` conversion.

### Module layout

| File | Contents |
|------|----------|
| `src/QdrantClient.jl` | Transport, connection, serialization, exports |
| `src/types.jl` | All struct definitions |
| `src/error.jl` | `QdrantError` |
| `src/collections.jl` | Collections & aliases API |
| `src/points.jl` | Points, payload, vectors, scroll, count, index |
| `src/search.jl` | Search, recommend, query |
| `src/discovery.jl` | Discovery |
| `src/snapshots.jl` | Snapshots |
| `src/distributed.jl` | Cluster status |
| `src/service.jl` | Health, metrics, telemetry |

