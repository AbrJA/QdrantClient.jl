# QdrantClient.jl Documentation

A high-performance, production-ready Julia client for the Qdrant vector database.

```@autodocs
Modules = [QdrantClient]
```

## Installation

```julia
] add QdrantClient
```

## Quick Start

```julia
using QdrantClient

# Create a client
client = Client(host="http://localhost", port=6333)

# Check server health
health_check(client)

# Create a collection
create_collection(
    client,
    "my_vectors";
    vectors=VectorParams(size=128, distance="Cosine")
)

# Insert points
points = [
    PointStruct(id=1, vector=rand(Float32, 128), payload=Dict("label" => "example1")),
    PointStruct(id=2, vector=rand(Float32, 128), payload=Dict("label" => "example2"))
]
upsert_points(client, "my_vectors", points)

# Search
results = search_points(
    client,
    "my_vectors",
    SearchRequest(vector=rand(Float32, 128), limit=5)
)

# Get recommendations
recommendations = recommend_points(
    client,
    "my_vectors",
    RecommendRequest(positive=[1], limit=5)
)
```

## Architecture

QdrantClient.jl follows these design principles:

1. **Type Safety**: All types defined with StructUtils for zero-cost JSON mapping
2. **Error Handling**: All HTTP exceptions wrapped in QdrantError
3. **Multiple Dispatch**: Core operations support explicit-client and default-client methods, plus keyword-based convenience constructors
4. **Connection Pooling**: HTTP.jl connection pooling for performance
5. **Complete Coverage**: All Qdrant API endpoints implemented

## Performance

- Vector operations use Float32 for efficiency
- Batch operations for high throughput
- Connection pooling per client
- Minimal allocations with StructUtils

## Development

See [CLAUDE.md](https://github.com/AbrJA/QdrantClient.jl/blob/master/CLAUDE.md) for development guidelines.

