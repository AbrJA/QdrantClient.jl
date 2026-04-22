<![CDATA[# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- **Dual transport** — HTTP/REST and gRPC, selected via Julia's multiple dispatch
- **Typed responses** — every endpoint returns `QdrantResponse{T}` with `.result`, `.status`, and `.time`
- **Zero-cost dispatch** — parametric `QdrantConnection{T}` eliminates runtime transport checks
- **Complete API coverage** — collections, points, queries, snapshots, payload indexes, facets, cluster status
- **Julian design** — keyword constructors, `@enum` distance, `Union` point IDs, `StructUtils` serialization

## Installation

```julia
using Pkg
Pkg.add("QdrantClient")
```

## Quick Start

```julia
using QdrantClient

# Connect (HTTP, default)
conn = QdrantConnection()

# Create a collection
create_collection(conn, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

# Insert points
upsert_points(conn, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
]; wait=true)

# Query
resp = query_points(conn, "demo"; query=Float32[1, 0, 0, 0], limit=5, with_payload=true)
resp.result.points   # Vector{ScoredPoint}
resp.status           # "ok"
resp.time             # server-side time in seconds
```

## Connection

```julia
# HTTP (default)
conn = QdrantConnection()
conn = QdrantConnection(host="qdrant.example.com", port=6333, api_key="secret", tls=true)

# gRPC
conn = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# Global default
set_client!(conn)
list_collections()  # uses global client
```

The connection type `QdrantConnection{HTTPTransport}` or `QdrantConnection{GRPCTransport}` drives dispatch — the same function names work with both transports.

## Response Envelope

Every API call returns `QdrantResponse{T}`:

```julia
struct QdrantResponse{T}
    result::T        # typed result
    status::String   # server status ("ok")
    time::Float64    # server-side duration (seconds)
end
```

```julia
resp = count_points(conn, "demo"; exact=true)
resp.result.count  # Int
resp.status        # "ok"
resp.time          # 0.00042
```

## API Reference

### Collections

```julia
list_collections(conn) -> QdrantResponse{Vector{CollectionDescription}}
create_collection(conn, name, config) -> QdrantResponse{Bool}
create_collection(conn, name; vectors=VectorParams(...)) -> QdrantResponse{Bool}
delete_collection(conn, name) -> QdrantResponse{Bool}
collection_exists(conn, name) -> QdrantResponse{Bool}
get_collection(conn, name) -> QdrantResponse{Dict{String,Any}}
update_collection(conn, name, update) -> QdrantResponse{Bool}
```

### Aliases

```julia
create_alias(conn, alias, collection) -> QdrantResponse{Bool}
delete_alias(conn, alias) -> QdrantResponse{Bool}
rename_alias(conn, old, new) -> QdrantResponse{Bool}
list_aliases(conn) -> QdrantResponse{Vector{AliasDescription}}
list_collection_aliases(conn, collection) -> QdrantResponse{Vector{AliasDescription}}
```

### Points

```julia
upsert_points(conn, collection, points; wait=false) -> QdrantResponse{UpdateResult}
get_points(conn, collection, ids; with_payload, with_vectors) -> QdrantResponse{Vector{Record}}
get_point(conn, collection, id) -> QdrantResponse{Record}
delete_points(conn, collection, ids_or_filter; wait=false) -> QdrantResponse{UpdateResult}
scroll_points(conn, collection; limit, filter, with_payload) -> QdrantResponse{ScrollResult}
count_points(conn, collection; filter, exact) -> QdrantResponse{CountResult}
batch_points(conn, collection, operations; wait=false) -> QdrantResponse{Vector{UpdateResult}}
```

### Payload Operations

```julia
set_payload(conn, collection, payload, ids_or_filter) -> QdrantResponse{UpdateResult}
overwrite_payload(conn, collection, payload, ids_or_filter) -> QdrantResponse{UpdateResult}
delete_payload(conn, collection, keys, ids_or_filter) -> QdrantResponse{UpdateResult}
clear_payload(conn, collection, ids; wait=false) -> QdrantResponse{UpdateResult}
```

### Vectors

```julia
update_vectors(conn, collection, points) -> QdrantResponse{UpdateResult}
delete_vectors(conn, collection, vector_names, ids; wait=false) -> QdrantResponse{UpdateResult}
```

### Query

```julia
query_points(conn, collection, request) -> QdrantResponse{QueryResult}
query_points(conn, collection; query, limit, kwargs...) -> QdrantResponse{QueryResult}
query_batch(conn, collection, requests) -> QdrantResponse{Vector{QueryResult}}
query_groups(conn, collection, request) -> QdrantResponse{GroupsResult}
facet(conn, collection, field; kwargs...) -> QdrantResponse{FacetResult}
```

### Snapshots

```julia
create_snapshot(conn, collection) -> QdrantResponse{SnapshotInfo}
list_snapshots(conn, collection) -> QdrantResponse{Vector{SnapshotInfo}}
delete_snapshot(conn, collection, name) -> QdrantResponse{Bool}
create_full_snapshot(conn) -> QdrantResponse{SnapshotInfo}
list_full_snapshots(conn) -> QdrantResponse{Vector{SnapshotInfo}}
delete_full_snapshot(conn, name) -> QdrantResponse{Bool}
```

### Payload Indexes

```julia
create_payload_index(conn, collection, field; field_schema, wait) -> QdrantResponse{UpdateResult}
delete_payload_index(conn, collection, field; wait) -> QdrantResponse{UpdateResult}
```

### Service

```julia
health_check(conn) -> QdrantResponse{HealthInfo}
get_version(conn) -> QdrantResponse{HealthInfo}
get_metrics(conn) -> QdrantResponse{String}
get_telemetry(conn) -> QdrantResponse{Dict{String,Any}}
cluster_status(conn) -> QdrantResponse{Dict{String,Any}}
```

## Type Reference

### Config Types

| Type | Purpose |
|------|---------|
| `CollectionConfig` | Collection creation parameters (vectors, hnsw, optimizers, wal) |
| `CollectionUpdate` | Collection update parameters |
| `VectorParams` | Vector field config (size, distance, hnsw_config, on_disk) |
| `HnswConfig` | HNSW index parameters (m, ef_construct) |
| `WalConfig` | Write-ahead log config |
| `OptimizersConfig` | Segment optimizer config |
| `SearchParams` | Query-time search parameters (hnsw_ef, exact, quantization) |
| `TextIndexParams` | Full-text index config (tokenizer, lowercase) |

### Distance

```julia
@enum Distance Cosine Euclid Dot Manhattan
```

### Point Types

```julia
Point(id, vector; payload)    # id::PointId = Union{Int, UUID}
NamedVector(name, vector)
```

### Filter Conditions

```julia
Filter(; must, should, must_not, min_should)
FieldCondition(; key, match, range)
MatchValue(; value)
MatchAny(; any)
MatchText(; text)
RangeCondition(; gt, gte, lt, lte)
HasIdCondition(; has_id)
IsEmptyCondition(; is_empty)
IsNullCondition(; is_null)
```

### Result Types

| Type | Fields |
|------|--------|
| `UpdateResult` | `operation_id::Int`, `status::String` |
| `CountResult` | `count::Int` |
| `Record` | `id::PointId`, `payload`, `vector` |
| `ScoredPoint` | `id::PointId`, `version::Int`, `score::Float64`, `payload`, `vector` |
| `ScrollResult` | `points::Vector{Record}`, `next_page_offset` |
| `QueryResult` | `points::Vector{ScoredPoint}` |
| `GroupResult` | `id`, `hits::Vector{ScoredPoint}` |
| `GroupsResult` | `groups::Vector{GroupResult}` |
| `SnapshotInfo` | `name::String`, `creation_time`, `size::Int`, `checksum` |
| `HealthInfo` | `title::String`, `version::String`, `commit::String` |
| `FacetResult` | `hits::Vector{FacetHit}` |
| `FacetHit` | `value`, `count::Int` |
| `CollectionDescription` | `name::String` |
| `AliasDescription` | `alias_name::String`, `collection_name::String` |

## gRPC Transport

The gRPC transport supports the same API surface. Pass a `GRPCTransport` to select it:

```julia
conn = QdrantConnection(GRPCTransport(host="localhost", port=6334))

# Same functions, dispatched to gRPC
create_collection(conn, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
query_points(conn, "demo"; query=Float32[1, 0, 0, 0], limit=5)
```

**Known limitation**: Proto3 does not encode the default enum value (0), so `field_schema="keyword"` in `create_payload_index` may not work over gRPC. Use `"integer"`, `"float"`, or `"text"` instead.

## Named Vectors

```julia
cfg = CollectionConfig(vectors=Dict(
    "image" => VectorParams(size=512, distance=Cosine),
    "text"  => VectorParams(size=768, distance=Dot),
))
create_collection(conn, "multi", cfg)

pts = [Point(id=1, vector=Dict(
    "image" => Float32.(randn(512)),
    "text"  => Float32.(randn(768)),
))]
upsert_points(conn, "multi", pts)

query_points(conn, "multi"; query=Float32.(randn(512)), using_="image", limit=10)
```

## Filtering

```julia
f = Filter(must=[
    FieldCondition(key="color", match=MatchValue(value="red")),
    FieldCondition(key="price", range=RangeCondition(gte=10.0, lte=100.0)),
])
query_points(conn, "demo"; query=Float32[1, 0, 0, 0], limit=5, filter=f)
```

## Error Handling

API errors throw `QdrantError`:

```julia
try
    get_collection(conn, "nonexistent")
catch e::QdrantError
    e.status   # HTTP status code (Int)
    e.message  # error message (String)
    e.detail   # optional parsed error body
end
```

## Requirements

- Julia 1.10+
- Qdrant server (tested with v1.9+)
- HTTP.jl, JSON.jl, StructUtils.jl
- For gRPC: ProtoBuf.jl, gRPCClient.jl

## License

MIT — see [LICENSE](LICENSE).
]]>