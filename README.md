# Qdrant.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AbrJA.github.io/Qdrant.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AbrJA.github.io/Qdrant.jl/dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- **Dual transport** — HTTP/REST and gRPC, selected via Julia's multiple dispatch
- **Typed responses** — every endpoint returns `QdrantResponse{T}` with `.result`, `.status`, and `.time`
- **Zero-cost dispatch** — parametric `QdrantClient{T}` eliminates runtime transport checks
- **Complete API coverage** — collections, points, queries, snapshots, payload indexes, facets, cluster, shards, health probes
- **Julian design** — keyword constructors, `@enum` distance, `Union` point IDs, `StructUtils` serialization

## Installation

```julia
using Pkg
Pkg.add("Qdrant")
```

## Quick Start

```julia
using Qdrant

# Connect (HTTP, default)
client = QdrantClient()

# Create a collection
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

# Insert points
upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
]; wait=true)

# Query
resp = query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=5, with_payload=true)
resp.result.points   # Vector{ScoredPoint}
resp.status           # "ok"
resp.time             # server-side time in seconds
```

## Connection

```julia
# HTTP (default)
client = QdrantClient()
client = QdrantClient(host="qdrant.example.com", port=6333, api_key="secret", tls=true)

# gRPC
client = QdrantClient(GRPCTransport(host="localhost", port=6334))

# Global default
set_client!(client)
list_collections()  # uses global client
```

The connection type `QdrantClient{HTTPTransport}` or `QdrantClient{GRPCTransport}` drives dispatch — the same function names work with both transports.

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
resp = count_points(client, "demo"; exact=true)
resp.result.count  # Int
resp.status        # "ok"
resp.time          # 0.00042
```

## API Reference

### Collections

```julia
list_collections(client) -> QdrantResponse{Vector{CollectionDescription}}
create_collection(client, name, config) -> QdrantResponse{Bool}
create_collection(client, name; vectors=VectorParams(...)) -> QdrantResponse{Bool}
delete_collection(client, name) -> QdrantResponse{Bool}
collection_exists(client, name) -> QdrantResponse{Bool}
get_collection(client, name) -> QdrantResponse{CollectionInfo}
get_collection_optimizations(client, name) -> QdrantResponse{OptimizationsStatus}
update_collection(client, name, update) -> QdrantResponse{Bool}
```

`get_collection` returns a typed `CollectionInfo` payload with strongly-typed
top-level fields and raw nested config dictionaries.

### Aliases

```julia
create_alias(client, alias, collection) -> QdrantResponse{Bool}
delete_alias(client, alias) -> QdrantResponse{Bool}
rename_alias(client, old, new) -> QdrantResponse{Bool}
list_aliases(client) -> QdrantResponse{Vector{AliasDescription}}
list_collection_aliases(client, collection) -> QdrantResponse{Vector{AliasDescription}}
```

### Points

```julia
upsert_points(client, collection, points; wait=false) -> QdrantResponse{UpdateResult}
get_points(client, collection, ids; with_payload, with_vectors) -> QdrantResponse{Vector{Record}}
get_point(client, collection, id) -> QdrantResponse{Record}
delete_points(client, collection, ids_or_filter; wait=false) -> QdrantResponse{UpdateResult}
scroll_points(client, collection; limit, filter, with_payload) -> QdrantResponse{ScrollResult}
count_points(client, collection; filter, exact) -> QdrantResponse{CountResult}
batch_points(client, collection, operations; wait=false) -> QdrantResponse{Vector{UpdateResult}}
```

### Payload Operations

```julia
set_payload(client, collection, payload, ids_or_filter) -> QdrantResponse{UpdateResult}
overwrite_payload(client, collection, payload, ids_or_filter) -> QdrantResponse{UpdateResult}
delete_payload(client, collection, keys, ids_or_filter) -> QdrantResponse{UpdateResult}
clear_payload(client, collection, ids; wait=false) -> QdrantResponse{UpdateResult}
```

### Vectors

```julia
update_vectors(client, collection, points) -> QdrantResponse{UpdateResult}
delete_vectors(client, collection, vector_names, ids; wait=false) -> QdrantResponse{UpdateResult}
```

### Query

```julia
query_points(client, collection, request) -> QdrantResponse{QueryResult}
query_points(client, collection; query, limit, kwargs...) -> QdrantResponse{QueryResult}
query_batch(client, collection, requests) -> QdrantResponse{Vector{QueryResult}}
query_groups(client, collection, request) -> QdrantResponse{GroupsResult}
facet(client, collection, field; kwargs...) -> QdrantResponse{FacetResult}
```

### Snapshots

```julia
create_snapshot(client, collection) -> QdrantResponse{SnapshotInfo}
list_snapshots(client, collection) -> QdrantResponse{Vector{SnapshotInfo}}
delete_snapshot(client, collection, name) -> QdrantResponse{Bool}
create_full_snapshot(client) -> QdrantResponse{SnapshotInfo}
list_full_snapshots(client) -> QdrantResponse{Vector{SnapshotInfo}}
delete_full_snapshot(client, name) -> QdrantResponse{Bool}
recover_from_snapshot(client, collection; location, priority) -> QdrantResponse{Bool}
```

### Payload Indexes

```julia
create_payload_index(client, collection, field; field_schema, wait) -> QdrantResponse{UpdateResult}
delete_payload_index(client, collection, field; wait) -> QdrantResponse{UpdateResult}
```

### Service

```julia
health_check(client) -> QdrantResponse{HealthInfo}
get_version(client) -> QdrantResponse{HealthInfo}
get_metrics(client) -> QdrantResponse{String}
get_telemetry(client) -> QdrantResponse{Dict{String,Any}}
healthz(client) -> QdrantResponse{String}
livez(client) -> QdrantResponse{String}
readyz(client) -> QdrantResponse{String}
get_issues(client) -> QdrantResponse{Dict{String,Any}}
clear_issues(client) -> QdrantResponse{Bool}
```

### Cluster & Distributed

```julia
cluster_status(client) -> QdrantResponse{ClusterStatus}
cluster_telemetry(client) -> QdrantResponse{Dict{String,Any}}
recover_current_peer(client) -> QdrantResponse{Bool}
remove_peer(client, peer_id; force=false) -> QdrantResponse{Bool}
collection_cluster_info(client, collection) -> QdrantResponse{CollectionClusterInfo}
update_collection_cluster(client, collection, operations) -> QdrantResponse{Bool}
```

### Shard Keys

```julia
list_shard_keys(client, collection) -> QdrantResponse{ShardKeysResult}
create_shard_key(client, collection, request) -> QdrantResponse{Bool}
delete_shard_key(client, collection, request) -> QdrantResponse{Bool}
```

### Typed vs Dynamic Responses

Most endpoints return typed structs in `.result` (for example,
`CollectionInfo`, `ClusterStatus`, `CollectionClusterInfo`, `ShardKeysResult`).
Some high-variance endpoints intentionally remain dynamic and return
`Dict{String,Any}`:

- `get_telemetry`
- `cluster_telemetry`
- `get_issues`

### Shard Snapshots

```julia
create_shard_snapshot(client, collection, shard_id) -> QdrantResponse{SnapshotInfo}
list_shard_snapshots(client, collection, shard_id) -> QdrantResponse{Vector{SnapshotInfo}}
delete_shard_snapshot(client, collection, shard_id, name) -> QdrantResponse{Bool}
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
| `HealthInfo` | `title::String`, `version::String` |
| `FacetResult` | `hits::Vector{FacetHit}` |
| `FacetHit` | `value`, `count::Int` |
| `CollectionDescription` | `name::String` |
| `AliasDescription` | `alias_name::String`, `collection_name::String` |
| `CollectionInfo` | `status`, `optimizer_status`, `points_count`, `indexed_vectors_count`, `segments_count`, `config`, `payload_schema` |
| `OptimizationsStatus` | `running`, `summary`, `queued`, `completed` |
| `ClusterStatus` | `status`, `peer_id`, `peers`, `raft_info`, `message_send_failures` |
| `LocalShardInfo` | `shard_id`, `points_count`, `state`, `shard_key` |
| `RemoteShardInfo` | `shard_id`, `peer_id`, `state`, `shard_key` |
| `ShardTransferInfo` | `shard_id`, `from`, `to`, `sync`, `to_shard_id`, `method`, `comment` |
| `CollectionClusterInfo` | `peer_id`, `shard_count`, `local_shards`, `remote_shards`, `shard_transfers` |
| `ShardKeysResult` | `shard_keys::Vector{Any}` |

## gRPC Transport

The gRPC transport supports the same API surface. Pass a `GRPCTransport` to select it:

```julia
client = QdrantClient(GRPCTransport(host="localhost", port=6334))

# Same functions, dispatched to gRPC
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))
query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=5)
```

**Known limitation**: Proto3 does not encode the default enum value (0), so `field_schema="keyword"` in `create_payload_index` may not work over gRPC. Use `"integer"`, `"float"`, or `"text"` instead.

## Named Vectors

```julia
cfg = CollectionConfig(vectors=Dict(
    "image" => VectorParams(size=512, distance=Cosine),
    "text"  => VectorParams(size=768, distance=Dot),
))
create_collection(client, "multi", cfg)

pts = [Point(id=1, vector=Dict(
    "image" => Float32.(randn(512)),
    "text"  => Float32.(randn(768)),
))]
upsert_points(client, "multi", pts)

query_points(client, "multi"; query=Float32.(randn(512)), using_="image", limit=10)
```

## Filtering

```julia
f = Filter(must=[
    FieldCondition(key="color", match=MatchValue(value="red")),
    FieldCondition(key="price", range=RangeCondition(gte=10.0, lte=100.0)),
])
query_points(client, "demo"; query=Float32[1, 0, 0, 0], limit=5, filter=f)
```

## Error Handling

API errors throw `QdrantError`:

```julia
try
    get_collection(client, "nonexistent")
catch e::QdrantError
    e.status   # HTTP status code (Int)
    e.message  # error message (String)
    e.detail   # optional parsed error body
end
```

## Requirements

- Julia 1.12+
- Qdrant server (tested with v1.9+)
- HTTP.jl, JSON.jl, StructUtils.jl
- For gRPC: ProtoBuf.jl, gRPCClient.jl

## License

MIT — see [LICENSE](LICENSE).