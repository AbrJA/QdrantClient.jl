# QdrantClient.jl

A high-performance, idiomatic Julia client for the [Qdrant](https://qdrant.tech/) vector database.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/dev)
[![Build Status](https://github.com/AbrJA/QdrantClient.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/QdrantClient.jl/actions?query=workflow%3ACI+branch%3Amaster)

---

## Features

- **Full API Coverage** — Collections, Points, Search, Recommendations, Discovery, Snapshots, Cluster, Service
- **Typed Structs** — `StructUtils.jl`-based type system with zero-cost JSON mapping and `omit_null` serialization
- **Multiple Dispatch** — Every endpoint accepts an explicit `QdrantConnection` or falls back to a global default
- **Connection Pooling** — `HTTP.jl` pool reused across requests for high throughput
- **Typed Errors** — All HTTP failures wrapped in `QdrantError` with status code and parsed detail
- **Flexible Point IDs** — `PointId = Union{Int, UUID}` accepted everywhere
- **Batch-First Design** — Batch variants (`search_batch`, `query_batch`, …) for all latency-sensitive paths

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

# ── Connection ──────────────────────────────────────────────────────────────
client = QdrantConnection()                                  # localhost:6333
client = QdrantConnection(host="qdrant.example.com",
                          port=6333, api_key="secret")       # remote + auth
set_client!(client)                                          # set global default

# ── Collections ─────────────────────────────────────────────────────────────
create_collection(client, "demo",
    CollectionConfig(vectors=VectorParams(size=4, distance=Cosine)))

# ── Points ───────────────────────────────────────────────────────────────────
upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0], payload=Dict("color" => "red")),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("color" => "blue")),
    Point(id=3, vector=Float32[0, 0, 1, 0], payload=Dict("color" => "green")),
]; wait=true)

# ── Search ───────────────────────────────────────────────────────────────────
hits = search_points(client, "demo",
    SearchRequest(vector=Float32[1, 0, 0, 0], limit=2, with_payload=true))
# => [Dict("id"=>1, "score"=>1.0, "payload"=>…), …]

# ── Query (universal API) ────────────────────────────────────────────────────
results = query_points(client, "demo",
    QueryRequest(query=Float32[1, 0, 0, 0], limit=2))

# ── Recommendations ──────────────────────────────────────────────────────────
recs = recommend_points(client, "demo",
    RecommendRequest(positive=[1], negative=[3], limit=2))

# ── Scroll ───────────────────────────────────────────────────────────────────
page = scroll_points(client, "demo"; limit=100, with_payload=true)

# ── Cleanup ──────────────────────────────────────────────────────────────────
delete_collection(client, "demo")
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

# Global default — omit the client argument anywhere
set_client!(client)
get_client()           # retrieve current global
```

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
list_collections(client)                         # → Dict with "collections" key
get_collection(client, "images")                 # → full collection info
collection_exists(client, "images")              # → Dict with "exists" key
update_collection(client, "images",
    CollectionUpdate(optimizers_config=OptimizersConfig(indexing_threshold=50_000)))
delete_collection(client, "images")              # → true
```

### Aliases

```julia
list_aliases(client)                                    # all aliases
list_collection_aliases(client, "images")               # aliases for one collection
create_alias(client, "images_v2", "images")             # create alias
rename_alias(client, "images_v2", "images_v3")          # rename
delete_alias(client, "images_v3")                       # delete
```

---

## Points

### Upsert

```julia
# Integer IDs
upsert_points(client, "demo", [
    Point(id=1, vector=Float32[1, 0, 0, 0]),
    Point(id=2, vector=Float32[0, 1, 0, 0], payload=Dict("label" => "cat")),
]; wait=true)

# UUID IDs
using UUIDs
upsert_points(client, "demo", [
    Point(id=uuid4(), vector=Float32[1, 0, 0, 0]),
])

# Named vectors (multi-vector collection)
upsert_points(client, "multimodal", [
    Point(id=1, vector=Dict{String,Vector{Float32}}(
        "image" => rand(Float32, 512),
        "text"  => rand(Float32, 768),
    )),
])
```

### Retrieve

```julia
get_points(client, "demo", [1, 2, 3]; with_payload=true)
get_points(client, "demo", 1)                    # single point
```

### Delete

```julia
delete_points(client, "demo", [1, 2])            # by ID list
delete_points(client, "demo", 1)                 # single ID
delete_points(client, "demo",                    # by filter
    Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]))
```

### Payload

```julia
# Set payload fields
set_payload(client, "demo", Dict("verified" => true), [1, 2])

# Set payload via filter
set_payload(client, "demo", Dict("archived" => true),
    Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]))

# Delete specific keys
delete_payload(client, "demo", ["verified"], [1])

# Remove all payload
clear_payload(client, "demo", [1, 2])
```

### Vectors

```julia
# Update vectors for existing points
update_vectors(client, "demo", [
    Point(id=1, vector=Float32[0.9, 0.1, 0, 0]),
])

# Delete a named vector field
delete_vectors(client, "multimodal", ["text"], [1, 2])
```

### Scroll & Count

```julia
# Scroll without filter
page = scroll_points(client, "demo"; limit=100, with_payload=true)
page["points"]     # vector of point dicts
page["next_page_offset"]

# Scroll with filter
page = scroll_points(client, "demo";
    filter=Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]),
    limit=50)

# Count all points
count_points(client, "demo")                     # approximate
count_points(client, "demo"; exact=true)         # exact (slower)

# Count with filter
count_points(client, "demo";
    filter=Filter(must=[FieldCondition(key="label", match=MatchValue(value="cat"))]))
```

### Payload Index

Indexes speed up filtered searches on payload fields.

```julia
# Simple type index
create_payload_index(client, "demo", "label"; field_schema="keyword")
create_payload_index(client, "demo", "price"; field_schema="float")
create_payload_index(client, "demo", "count"; field_schema="integer")

# Full-text index
create_payload_index(client, "demo", "description";
    field_schema=TextIndexParams(tokenizer="word", lowercase=true))

delete_payload_index(client, "demo", "label")
```

### Batch Operations

```julia
batch_points(client, "demo", [
    Dict("upsert" => Dict("points" => [
        Dict("id" => 10, "vector" => Float32[1,0,0,0]),
    ])),
    Dict("delete" => Dict("points" => [5, 6])),
])
```

---

## Search

### Basic Search

```julia
# Struct form
hits = search_points(client, "demo",
    SearchRequest(vector=Float32[1, 0, 0, 0], limit=5, with_payload=true))

# Keyword shorthand
hits = search_points(client, "demo";
    vector=Float32[1, 0, 0, 0], limit=5, with_payload=true)

# Named vector
hits = search_points(client, "multimodal",
    SearchRequest(
        vector=NamedVector(name="image", vector=rand(Float32, 512)),
        limit=5))

# Filtered search
hits = search_points(client, "demo",
    SearchRequest(
        vector=Float32[1, 0, 0, 0],
        limit=5,
        filter=Filter(must=[
            FieldCondition(key="label", match=MatchValue(value="cat"))
        ])))

# With HNSW tuning
hits = search_points(client, "demo",
    SearchRequest(
        vector=Float32[1, 0, 0, 0],
        limit=5,
        params=SearchParams(hnsw_ef=128, exact=false)))
```

### Batch Search

```julia
batch = search_batch(client, "demo", [
    SearchRequest(vector=Float32[1, 0, 0, 0], limit=3),
    SearchRequest(vector=Float32[0, 1, 0, 0], limit=3),
])
# => [hits1, hits2]
```

### Grouped Search

```julia
search_groups(client, "demo", Dict(
    "vector" => Float32[1, 0, 0, 0],
    "limit"  => 10,
    "group_by" => "label",
); group_size=2)
```

---

## Recommendations

```julia
# Positive examples only
recs = recommend_points(client, "demo",
    RecommendRequest(positive=[1, 2], limit=5))

# Positive + negative examples
recs = recommend_points(client, "demo",
    RecommendRequest(positive=[1, 2], negative=[3], limit=5, with_payload=true))

# Named vector namespace
recs = recommend_points(client, "multimodal",
    RecommendRequest(positive=[1], limit=5, using_="image"))

# Lookup vectors from a different collection
recs = recommend_points(client, "demo",
    RecommendRequest(
        positive=[1],
        limit=5,
        lookup_from=LookupLocation(collection="other_col", vector="image")))

# Batch
batch = recommend_batch(client, "demo", [
    RecommendRequest(positive=[1], limit=3),
    RecommendRequest(positive=[2], limit=3),
])
```

---

## Query (Universal API)

The `query_points` API is the most flexible endpoint, supporting nearest-neighbor,
recommendations, and re-ranking in one call.

```julia
# Nearest-neighbor by vector
query_points(client, "demo",
    QueryRequest(query=Float32[1, 0, 0, 0], limit=5))

# Recommend by point ID
query_points(client, "demo",
    QueryRequest(query=Dict("recommend" => Dict("positive" => [1], "negative" => [3])),
                 limit=5))

# Re-rank with named vector
query_points(client, "multimodal",
    QueryRequest(query=rand(Float32, 512), limit=5, using_="image"))

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
```

---

## Discovery

Discovery finds points near a target while respecting a context of positive/negative pairs.

```julia
discover_points(client, "demo",
    DiscoverRequest(
        target=Float32[1, 0, 0, 0],
        limit=5,
        context=[Dict("positive" => 1, "negative" => 3)]))

# Batch
discover_batch(client, "demo", [
    DiscoverRequest(target=Float32[1, 0, 0, 0], limit=3,
                    context=[Dict("positive" => 1, "negative" => 2)]),
])
```

---

## Filters

Filters can be used in `delete_points`, `set_payload`, `scroll_points`, `count_points`,
`search_points`, `query_points`, `recommend_points`, and `discover_points`.

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
snap["name"]                                     # snapshot file name

snaps = list_snapshots(client, "demo")

delete_snapshot(client, "demo", snap["name"])
```

---

## Cluster & Service

```julia
# Health check
health = health_check(client)
health["status"]                                 # "healthy" or "unhealthy"

# Prometheus-format metrics
metrics = get_metrics(client)

# Telemetry
telemetry = get_telemetry(client)

# Cluster / distributed
cs = cluster_status(client)
```

---

## Type Reference

### Core Types

| Type | Purpose |
|------|---------|
| `QdrantConnection` | Client connection (host, port, api_key, tls, timeout) |
| `QdrantError` | Typed error with `status`, `message`, `detail` |
| `PointId` | `Union{Int, UUID}` |

### Collection Types

| Type | Purpose |
|------|---------|
| `CollectionConfig` | Full collection creation config |
| `CollectionUpdate` | Patch payload for `update_collection` |
| `CollectionParamsDiff` | Mutable replication/consistency params |
| `VectorParams` | Dense vector field config (size, distance, HNSW, quantization) |
| `SparseVectorParams` | Sparse vector field config |
| `HnswConfig` | HNSW index tuning |
| `WalConfig` | Write-ahead log config |
| `OptimizersConfig` | Segment optimizer config |

### Quantization Types

| Type | Purpose |
|------|---------|
| `ScalarQuantization` | Scalar (int8) quantization wrapper |
| `ScalarQuantizationConfig` | Scalar quantization parameters |
| `ProductQuantization` | PQ quantization wrapper |
| `ProductQuantizationConfig` | PQ compression parameters |
| `BinaryQuantization` | Binary quantization wrapper |
| `BinaryQuantizationConfig` | Binary quantization parameters |
| `QuantizationSearchParams` | Per-query quantization overrides |

### Point Types

| Type | Purpose |
|------|---------|
| `Point` | Point with `id`, `vector`, optional `payload` |
| `NamedVector` | `(name, vector)` for multi-vector points |
| `LookupLocation` | Cross-collection vector lookup |

### Filter Types

| Type | Purpose |
|------|---------|
| `Filter` | Compound filter (`must`, `should`, `must_not`) |
| `FieldCondition` | Condition on a payload field |
| `MatchValue` | Exact value match |
| `MatchAny` | Match any of a list |
| `MatchText` | Full-text match |
| `RangeCondition` | Numeric range (`gte`, `gt`, `lte`, `lt`) |
| `HasIdCondition` | Filter by point IDs |
| `IsEmptyCondition` | Match empty fields |
| `IsNullCondition` | Match null fields |

### Request Types

| Type | Purpose |
|------|---------|
| `SearchRequest` | Nearest-neighbor search |
| `RecommendRequest` | Recommendation from examples |
| `QueryRequest` | Universal query (NN + recommend + rerank) |
| `DiscoverRequest` | Discovery with context pairs |
| `SearchParams` | Search-time HNSW / quantization overrides |

### Distance Values

```julia
Cosine     # cosine similarity (normalized vectors)
Euclid     # Euclidean distance
Dot        # dot-product / inner product
Manhattan  # L1 distance
```

---

## Error Handling

```julia
try
    search_points(client, "missing_collection",
        SearchRequest(vector=Float32[1,0,0,0], limit=5))
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

# These are now equivalent:
search_points(get_client(), "demo", SearchRequest(vector=q, limit=5))
search_points("demo", SearchRequest(vector=q, limit=5))
```

---

## Development

```bash
# Start a local Qdrant instance
docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant

# Run tests
julia --project=. test/runtests.jl

# Format code
julia --project=. -e 'using JuliaFormatter; format(".")'

# Quality check
julia --project=. -e 'using Aqua; Aqua.test_all(QdrantClient)'
```

---

## License

[MIT](LICENSE)
