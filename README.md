# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/dev)
[![Build Status](https://github.com/AbrJA/QdrantClient.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/QdrantClient.jl/actions?query=workflow%3ACI+branch%3Amaster)

---

## Features

- **Full API Coverage** — Collections, Points, Query (universal), Snapshots, Cluster, Service
- **Dual Transport** — HTTP/REST (default) and gRPC (~2-10× faster for bulk operations)
- **Typed Responses** — Every endpoint returns a concrete Julia type (`UpdateResponse`, `QueryResponse`, `ScrollResponse`, etc.) for type-stable downstream code
- **Multiple Dispatch** — Every endpoint accepts an explicit `QdrantConnection` or falls back to a global default
- **Connection Pooling** — `HTTP.jl` pool reused across requests for high throughput
- **Typed Errors** — All HTTP failures wrapped in `QdrantError` with status code and parsed detail
- **Flexible Point IDs** — `PointId = Union{Int, UUID}` accepted everywhere
- **Batch-First Design** — Batch variants (`query_batch`, `batch_points`, …) for all latency-sensitive paths

---

## What's New in v1.0

### Breaking Changes

- **Typed responses everywhere** — Functions now return typed structs instead of raw `Dict`:
  - `upsert_points` → `UpdateResponse(operation_id, status)`
  - `query_points` → `QueryResponse(points::Vector{ScoredPoint})`
  - `scroll_points` → `ScrollResponse(points::Vector{Record}, next_page_offset)`
  - `count_points` → `CountResponse(count)`
  - `create_snapshot` → `SnapshotInfo(name, creation_time, size, checksum)`
  - `health_check` → `HealthResponse(title, version)`

- **Removed deprecated endpoints** — The following functions have been removed in favor of the universal `query_points` API:
  - `search_points` / `search_batch` / `search_groups`
  - `recommend_points` / `recommend_batch` / `recommend_groups`
  - `discover_points` / `discover_batch`
  - `SearchRequest`, `RecommendRequest`, `DiscoverRequest` types

- **Removed `execute()` internal** — All HTTP calls now use direct `HTTP.request`.

### New Features

- **gRPC transport** via `GRPCTransport` — binary protocol for high-throughput workloads
- **`query_groups`** — grouped query endpoint
- **`facet`** — faceted search on payload fields
- **`search_matrix_pairs` / `search_matrix_offsets`** — distance matrix endpoints

---

## Installation

```julia
] add QdrantClient
```

Requires Julia 1.12+.

---

## Quick Start

```julia
using QdrantClient

# ── Connection (HTTP, default) ──────────────────────────────────────────
client = QdrantConnection()                                  # localhost:6333
client = QdrantConnection(host="qdrant.example.com",
                          port=6333, api_key="secret")       # remote + auth

# ── Connection (gRPC, ~2-10× faster) ────────────────────────────────────
client = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# ── Collections ─────────────────────────────────────────────────────────
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
# => true

# ── Points ───────────────────────────────────────────────────────────────
resp = upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
]; wait=true)
# => UpdateResponse(operation_id=0, status="completed")

# ── Query (universal API) ────────────────────────────────────────────────
results = query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=2, with_payload=true)
# => QueryResponse with results.points::Vector{ScoredPoint}

# ── Scroll ───────────────────────────────────────────────────────────────
page = scroll_points(client, "demo"; limit=100, with_payload=true)
# => ScrollResponse(points::Vector{Record}, next_page_offset)

# ── Cleanup ──────────────────────────────────────────────────────────────
delete_collection(client, "demo")  # => true
```

---

## Connection & Authentication

```julia
# Plain (no TLS)
client = QdrantConnection()
client = QdrantConnection(host="myhost", port=6333)

# With API key
client = QdrantConnection(host="cloud.qdrant.io", port=6333,
                          api_key="your-api-key", tls=true)

# Custom timeout (seconds)
client = QdrantConnection(host="localhost", port=6333, timeout=60)

# gRPC transport
client = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# Global default — omit the client argument anywhere
set_client!(client)
get_client()
```

---

## gRPC Transport

gRPC uses Protocol Buffers for binary serialization, offering significantly better performance for bulk operations (upserts, queries, scrolls).

```julia
# Create a gRPC connection
grpc = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# All API functions work identically — transport is selected automatically
create_collection(grpc, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
upsert_points(grpc, "demo", [Point(id=1, vector=Float32[1,0,0,0])])
query_points(grpc, "demo"; query=Float32[1,0,0,0], limit=5)
```

### gRPC Limitations

Due to Proto3 wire format constraints, the following limitations apply:

- **`create_payload_index` with `"keyword"` type** — Proto3 does not send the default enum value (`FieldType.FieldTypeKeyword = 0`) over the wire, so creating a keyword index silently creates an integer index instead. **Workaround:** Use the HTTP transport for `create_payload_index` with keyword fields, or create keyword indexes before switching to gRPC.
- **`get_point` (single point)** — Not available over gRPC; use `get_points(client, collection, [id])` instead.
- **Snapshot download** — gRPC snapshot operations create/list/delete snapshots but do not support downloading snapshot files.

---

## Collections

### Creating a Collection

```julia
# Simple dense vectors
create_collection(client, "images",
    CollectionConfig(vectors=VectorParams(size=512, distance=Cosine)))

# Keyword shorthand
create_collection(client, "images"; vectors=VectorParams(size=512, distance=Cosine))

# Named (multi-vector) collection
create_collection(client, "multimodal", CollectionConfig(
    vectors=Dict{String,VectorParams}(
        "image" => VectorParams(size=512, distance=Cosine),
        "text"  => VectorParams(size=768, distance=Dot),
    )
))

# Full configuration
create_collection(client, "tuned", CollectionConfig(
    vectors=VectorParams(size=128, distance=Euclid),
    hnsw_config=HnswConfig(m=32, ef_construct=200),
    optimizers_config=OptimizersConfig(indexing_threshold=20_000),
    quantization_config=ScalarQuantization(
        scalar=ScalarQuantizationConfig(type="int8", quantile=0.99, always_ram=true)
    ),
    on_disk_payload=true,
    shard_number=2,
))
```

### Collection Operations

```julia
list_collections(client)              # => Vector{CollectionDescription}
get_collection(client, "images")      # => Dict{String,Any} (full info)
collection_exists(client, "images")   # => true/false
update_collection(client, "images",
    CollectionUpdate(optimizers_config=OptimizersConfig(indexing_threshold=50_000)))
                                      # => true
delete_collection(client, "images")   # => true
```

### Aliases

```julia
list_aliases(client)                                    # => Vector{AliasDescription}
list_collection_aliases(client, "images")               # => Vector{AliasDescription}
create_alias(client, "images_v2", "images")             # => true
rename_alias(client, "images_v2", "images_v3")          # => true
delete_alias(client, "images_v3")                       # => true
```

---

## Points

### Upsert

```julia
# Integer IDs — returns UpdateResponse
resp = upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0]),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("label" => "cat")),
]; wait=true)
resp.status  # "completed"

# UUID IDs
using UUIDs
upsert_points(client, "demo", [
    Point(id=uuid4(), vector=Float32[1, 0, 0, 0]),
])
```

### Retrieve

```julia
records = get_points(client, "demo", [1, 2, 3]; with_payload=true)
# => Vector{Record}  — each Record has .id, .payload, .vector

record = get_point(client, "demo", 1)  # => Record (HTTP only)
```

### Delete

```julia
delete_points(client, "demo", [1, 2])   # => UpdateResponse
delete_points(client, "demo", 1)        # single ID
delete_points(client, "demo",           # by filter
    Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]))
```

### Payload

```julia
set_payload(client, "demo", Dict("verified" => true), [1, 2])
overwrite_payload(client, "demo", Dict("verified" => true), [1])
delete_payload(client, "demo", ["verified"], [1])
clear_payload(client, "demo", [1, 2])
# All return UpdateResponse
```

### Vectors

```julia
update_vectors(client, "demo", [
    Point(id=1, vector=Float32[0.9, 0.1, 0, 0]),
])  # => UpdateResponse

delete_vectors(client, "multimodal", ["text"], [1, 2])  # => UpdateResponse
```

### Scroll & Count

```julia
page = scroll_points(client, "demo"; limit=100, with_payload=true)
# => ScrollResponse
page.points             # Vector{Record}
page.next_page_offset   # nothing or next offset

# Count
c = count_points(client, "demo"; exact=true)
# => CountResponse
c.count  # 42

# With filter
count_points(client, "demo";
    filter=Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]))
```

### Payload Index

```julia
create_payload_index(client, "demo", "label"; field_schema="keyword")
# => UpdateResponse

create_payload_index(client, "demo", "description";
    field_schema=TextIndexParams(tokenizer="word", lowercase=true))

delete_payload_index(client, "demo", "label")
# => UpdateResponse
```

### Batch Operations

```julia
results = batch_points(client, "demo", [
    Dict("upsert" => Dict("points" => [
        Dict("id" => 10, "vector" => Float32[1,0,0,0]),
    ])),
    Dict("delete" => Dict("points" => [5, 6])),
])
# => Vector{UpdateResponse}
```

---

## Query (Universal API)

The `query_points` API is the single endpoint for nearest-neighbor search,
recommendations, discovery, and re-ranking. It replaces the deprecated
`search_points`, `recommend_points`, and `discover_points`.

```julia
# Nearest-neighbor search
results = query_points(client, "demo",
    QueryRequest(query=Float32[1, 0, 0, 0], limit=5))
# => QueryResponse
results.points  # Vector{ScoredPoint} — each has .id, .version, .score, .payload, .vector

# With kwargs
query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=5, with_payload=true)

# Recommendation via query API
query_points(client, "demo",
    QueryRequest(query=Dict("recommend" => Dict("positive" => [1])), limit=5))

# Prefetch + re-rank (two-stage retrieval)
query_points(client, "demo",
    QueryRequest(
        query=Float32[1, 0, 0, 0],
        limit=5,
        prefetch=[Dict("query" => Float32[1, 0, 0, 0], "limit" => 50)]))

# Batch
query_batch(client, "demo", [
    QueryRequest(query=Float32[1, 0, 0, 0], limit=3),
    QueryRequest(query=Float32[0, 1, 0, 0], limit=3),
])
# => Vector{QueryResponse}

# Grouped query
query_groups(client, "demo"; query=Float32[1, 0, 0, 0], group_by="label",
    limit=10, group_size=2)
# => GroupsResponse
```

---

## Faceted Search

```julia
result = facet(client, "demo"; key="color", limit=10)
# => FacetResponse
result.hits  # Vector{FacetHit} — each has .value, .count
```

---

## Filters

Filters can be used in `delete_points`, `set_payload`, `scroll_points`, `count_points`,
and `query_points`.

```julia
# Exact keyword match
Filter(must=[FieldCondition(key="color", match=MatchValue(value="red"))])

# Match any of several values
Filter(must=[FieldCondition(key="color", match=MatchAny(any=["red", "blue"]))])

# Numeric range
Filter(must=[FieldCondition(key="price", range=RangeCondition(gte=10.0, lte=99.99))])

# Full-text match
Filter(must=[FieldCondition(key="description", match=MatchText(text="hello world"))])

# Filter by point ID
Filter(must=[HasIdCondition(has_id=[1, 2, 3])])

# Compound — must AND should
Filter(
    must=[FieldCondition(key="active", match=MatchValue(value=true))],
    should=[
        FieldCondition(key="color", match=MatchValue(value="red")),
        FieldCondition(key="color", match=MatchValue(value="blue")),
    ])

# Negation
Filter(must_not=[FieldCondition(key="archived", match=MatchValue(value=true))])
```

---

## Snapshots

```julia
snap = create_snapshot(client, "demo")
# => SnapshotInfo
snap.name              # snapshot file name
snap.creation_time
snap.size

snaps = list_snapshots(client, "demo")   # => Vector{SnapshotInfo}
delete_snapshot(client, "demo", snap.name)  # => true

# Full storage snapshots
create_full_snapshot(client)             # => SnapshotInfo
list_full_snapshots(client)              # => Vector{SnapshotInfo}
delete_full_snapshot(client, snap.name)  # => true
```

---

## Cluster & Service

```julia
health = health_check(client)
# => HealthResponse
health.title    # "qdrant - vectorass database"
health.version  # "1.x.y"

get_version(client)          # => HealthResponse
metrics = get_metrics(client)  # => String (Prometheus format)
telemetry = get_telemetry(client)  # => Dict{String,Any}
cluster_status(client)       # => Dict{String,Any}
```

---

## Response Type Reference

| Type | Fields | Returned By |
|------|--------|-------------|
| `UpdateResponse` | `operation_id::Int`, `status::String` | `upsert_points`, `delete_points`, `set_payload`, `clear_payload`, `create_payload_index`, etc. |
| `QueryResponse` | `points::Vector{ScoredPoint}` | `query_points`, `query_batch` |
| `ScoredPoint` | `id::PointId`, `version::Int`, `score::Float64`, `payload`, `vector` | (nested in QueryResponse) |
| `ScrollResponse` | `points::Vector{Record}`, `next_page_offset` | `scroll_points` |
| `Record` | `id::PointId`, `payload`, `vector` | `get_points`, `get_point`, (nested in ScrollResponse) |
| `CountResponse` | `count::Int` | `count_points` |
| `GroupsResponse` | `groups::Vector{GroupResult}` | `query_groups` |
| `GroupResult` | `id`, `hits::Vector{ScoredPoint}` | (nested in GroupsResponse) |
| `SnapshotInfo` | `name`, `creation_time`, `size`, `checksum` | `create_snapshot`, `list_snapshots` |
| `CollectionDescription` | `name::String` | `list_collections` |
| `AliasDescription` | `alias_name::String`, `collection_name::String` | `list_aliases` |
| `HealthResponse` | `title::String`, `version::String` | `health_check`, `get_version` |
| `FacetResponse` | `hits::Vector{FacetHit}` | `facet` |
| `FacetHit` | `value`, `count::Int` | (nested in FacetResponse) |

### Core Types

| Type | Purpose |
|------|---------|
| `QdrantConnection` | Client connection (HTTP or gRPC transport) |
| `QdrantError` | Typed error with `status`, `message`, `detail` |
| `PointId` | `Union{Int, UUID}` |
| `GRPCTransport` | gRPC transport configuration |

### Collection Types

| Type | Purpose |
|------|---------|
| `CollectionConfig` | Full collection creation config |
| `CollectionUpdate` | Patch payload for `update_collection` |
| `VectorParams` | Dense vector field config (size, distance, HNSW, quantization) |
| `SparseVectorParams` | Sparse vector field config |
| `HnswConfig` | HNSW index tuning |
| `WalConfig` | Write-ahead log config |
| `OptimizersConfig` | Segment optimizer config |

### Quantization Types

| Type | Purpose |
|------|---------|
| `ScalarQuantization` | Scalar (int8) quantization wrapper |
| `ProductQuantization` | PQ quantization wrapper |
| `BinaryQuantization` | Binary quantization wrapper |

### Filter Types

| Type | Purpose |
|------|---------|
| `Filter` | Compound filter (`must`, `should`, `must_not`) |
| `FieldCondition` | Condition on a payload field |
| `MatchValue` | Exact value match |
| `MatchAny` | Match any of a list |
| `MatchText` | Full-text match |
| `RangeCondition` | Numeric range |
| `HasIdCondition` | Filter by point IDs |

### Distance Values

```julia
Cosine     # cosine similarity (normalized vectors)
Euclid     # Euclidean distance
Dot        # dot-product / inner product
Manhattan  # L1 distance
```

---

## Migration from v0.x

| v0.x | v1.0 |
|------|------|
| `search_points(c, col, SearchRequest(...))` | `query_points(c, col, QueryRequest(query=..., limit=...))` |
| `recommend_points(c, col, RecommendRequest(...))` | `query_points(c, col, QueryRequest(query=Dict("recommend" => ...), limit=...))` |
| `discover_points(c, col, DiscoverRequest(...))` | `query_points(c, col, QueryRequest(query=Dict("discover" => ...), limit=...))` |
| `result["points"]` (Dict access) | `result.points` (typed struct field) |
| `result["status"]` | `result.status` |

---

## Error Handling

```julia
try
    query_points(client, "missing_collection";
        query=Float32[1,0,0,0], limit=5)
catch err
    if err isa QdrantError
        println("HTTP $(err.status): $(err.message)")
        println("Detail: $(err.detail)")
    end
end
```

---

## Global Client

All exported functions accept an optional first `QdrantConnection` argument. When omitted,
a global default is used:

```julia
set_client!(QdrantConnection(host="prod-qdrant", port=6333, api_key="key"))

# These are equivalent:
query_points(get_client(), "demo"; query=q, limit=5)
query_points("demo"; query=q, limit=5)
```

---

## Development

```bash
# Start a local Qdrant instance (HTTP + gRPC)
docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant

# Run tests
julia --project=. -e 'using Pkg; Pkg.test()'
```

---

## License

[MIT](LICENSE)
