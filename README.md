# QdrantClient.jl

A high-performance, production-ready Julia client for the [Qdrant](https://qdrant.tech/) vector database.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AbrJA.github.io/QdrantClient.jl/dev)
[![Build Status](https://github.com/AbrJA/QdrantClient.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/QdrantClient.jl/actions?query=workflow%3ACI+branch%3Amaster)

## Features

- **Full API Coverage**: Collections, Points, Search, Recommendations, Discovery, Snapshots, Distributed operations, Service endpoints
- **Type Safety**: StructUtils-based type system with zero-cost JSON mapping
- **Multiple Dispatch**: Explicit client support with convenient global defaults
- **Connection Pooling**: HTTP.jl global connection pooling for high performance
- **Error Handling**: All HTTP exceptions wrapped in typed `QdrantError`
- **Production Ready**: Comprehensive testing, validation, and documentation

## Installation

```julia
] add QdrantClient
```

## Quick Start

```julia
using QdrantClient

# Create a client
client = Client(host="http://localhost", port=6333)

# List collections
collections(client)

# Create a collection
create_collection(
    client,
    "my_vectors";
    vectors=VectorParams(size=128, distance="Cosine")
)

# Upsert points
points = [
    PointStruct(id=1, vector=rand(Float32, 128), payload=Dict("name" => "point1")),
    PointStruct(id=2, vector=rand(Float32, 128), payload=Dict("name" => "point2")),
]
upsert_points(client, "my_vectors", points)

# Search for similar vectors
results = search_points(
    client,
    "my_vectors",
    SearchRequest(vector=rand(Float32, 128), limit=5)
)

# Get recommendations
recs = recommend_points(
    client,
    "my_vectors",
    RecommendRequest(positive=[1], limit=5)
)

# Discover new vectors
discovered = discover_points(
    client,
    "my_vectors",
    DiscoverRequest(target=1, limit=5)
)

# Count points
count_result = count_points(client, "my_vectors")

# Scroll through points
scroll_result = scroll_points(client, "my_vectors", limit=100)

# Delete points
delete_points(client, "my_vectors", [1, 2])

# Delete collection
delete_collection(client, "my_vectors")
```

## API Overview

### Collections
- `collections(client)` - List all collections
- `create_collection(client, name, config)` - Create a collection from a `CollectionConfig`
- `create_collection(client, name; kwargs...)` - Create a collection with keyword configuration
- `get_collection_info(client, name)` - Get collection information
- `update_collection(client, name, config)` - Update collection configuration from a `CollectionUpdate`
- `update_collection(client, name; kwargs...)` - Update collection configuration with keyword arguments
- `delete_collection(client, name)` - Delete a collection
- `collection_exists(client, name)` - Check if collection exists
- `list_aliases(client)` - List all aliases
- `create_alias(client, alias, collection)` - Create an alias
- `delete_alias(client, alias)` - Delete an alias

### Points
- `upsert_points(client, collection, points; wait=true)` - Insert or update points
- `delete_points(client, collection, ids; wait=true)` - Delete points
- `retrieve_points(client, collection, ids; with_vectors=true, with_payload=true)` - Retrieve points
- `batch_points(client, collection, operations; wait=true)` - Batch operations
- `scroll_points(client, collection; filter=nothing, limit=10)` - Scroll through points
- `count_points(client, collection; filter=nothing)` - Count points
- `set_payload(client, collection, payload, points; wait=true)` - Set point payloads
- `delete_payload(client, collection, keys, points; wait=true)` - Delete payload fields
- `clear_payload(client, collection, points; wait=true)` - Clear all payloads
- `update_vectors(client, collection, points; wait=true)` - Update vectors
- `delete_vectors(client, collection, names, points; wait=true)` - Delete vector fields

### Search & Recommendations
- `search_points(client, collection, request)` - Search similar vectors
- `search_batch(client, collection, requests)` - Batch search
- `search_with_groups(client, collection, request; group_size=1)` - Grouped search
- `recommend_points(client, collection, request)` - Get recommendations
- `recommend_batch(client, collection, requests)` - Batch recommendations
- `recommend_with_groups(client, collection, request; group_size=1)` - Grouped recommendations

### Discovery & Query
- `discover_points(client, collection, request)` - Discover new points
- `discover_batch(client, collection, requests)` - Batch discovery
- `query_points(client, collection, request)` - Advanced query
- `query_batch(client, collection, requests)` - Batch queries
- `query_with_groups(client, collection, request; group_size=1)` - Grouped queries

### Snapshots
- `create_snapshot(client, collection)` - Create a snapshot
- `list_snapshots(client, collection)` - List snapshots
- `delete_snapshot(client, collection, snapshot_name)` - Delete a snapshot
- `recover_snapshot(client, collection, snapshot_name; priority="large_first")` - Recover from snapshot

### Distributed
- `cluster_status(client)` - Get cluster status
- `get_peer(client, peer_id)` - Get peer information
- `recover_peer(client, peer_id)` - Recover a peer

### Service
- `health_check(client)` - Check server health
- `get_metrics(client)` - Get server metrics
- `get_telemetry(client)` - Get server telemetry

## Configuration

### Using Global Client

```julia
using QdrantClient

# Set global default client
set_global_client(Client(host="http://qdrant.example.com", port=6333, api_key="your-api-key"))

# All functions will use global client if not explicitly provided
collections()  # Uses global client
```

### Explicit Client Parameter

```julia
client = Client(host="http://localhost", port=6333)
collections(client)  # Explicit client
```

## Error Handling

All HTTP errors are wrapped in `QdrantError`:

```julia
try
    search_points(client, "nonexistent", SearchRequest(vector=rand(128), limit=1))
catch err
    if err isa QdrantError
        println("Error $(err.status): $(err.message)")
        println("Details: $(err.detail)")
    end
end
```

## Performance Notes

- Connection pooling is automatically used for each client
- All operations support batch processing for better throughput
- Vectors are kept as `Float32` for memory efficiency
- StructUtils provides zero-cost JSON serialization

## Development

See [CLAUDE.md](CLAUDE.md) for development guidelines and architecture details.

## License

MIT License (see [LICENSE](LICENSE) file)

## Contributing

Contributions welcome! Please follow the style guide in CLAUDE.md.

