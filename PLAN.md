# QdrantClient.jl Full Implementation Plan

## Context

The user requests a full implementation of QdrantClient.jl from scratch, following the architectural guidelines in CLAUDE.md. The current codebase has basic scaffolding but lacks proper error handling, type safety, and comprehensive API coverage. The package also contains boilerplate Example.jl code from a template that needs removal.

The Qdrant API is defined in a 520KB openapi.json file which serves as the source of truth. The implementation must adhere to strict technical requirements from CLAUDE.md: mandatory QdrantError wrapping of all HTTP exceptions, StructUtils.jl integration for zero-cost JSON mapping, multiple dispatch design with explicit client support, and separate module concerns.

## Recommended Approach

### 1. Package Cleanup and Restructuring

**Remove boilerplate:**
- Delete `src/Example.jl` (placeholder module)
- Delete `src/usage.jl` (example usage file)
- Update `test/runtests.jl` to test QdrantClient instead of Example
- Update `docs/make.jl` and `docs/src/index.md` for QdrantClient documentation
- Update README.md with actual package information

**Fix Project.toml:**
- Add `[compat]` section with version bounds for Julia, HTTP, JSON, StructUtils
- Add `[extras]` and `[targets]` sections for test/documentation dependencies
- Remove unused dependencies

### 2. Core Architecture Implementation

**File Structure:**
```
src/
├── QdrantClient.jl              # Main module, exports, includes
├── error.jl                     # QdrantError and error handling
├── client.jl                    # Client struct, HTTP layer, authentication
├── types.jl                     # All StructUtils-based type definitions
├── collections.jl               # Collections API
├── points.jl                    # Points API  
├── search.jl                    # Search API
├── discovery.jl                 # Discovery API
├── service.jl                   # Service endpoints
├── snapshots.jl                 # Snapshot management
└── distributed.jl               # Distributed operations
```

**Implementation Order:**
1. `error.jl` - Foundation for error handling
2. `types.jl` - Core type definitions from OpenAPI schemas
3. `client.jl` - HTTP client with connection pooling and authentication
4. `collections.jl` - First API category (establishes pattern)
5. `points.jl`, `search.jl`, `discovery.jl` - Remaining APIs
6. `service.jl`, `snapshots.jl`, `distributed.jl` - Supporting APIs

### 3. Error Handling (Mandatory per CLAUDE.md)

```julia
struct QdrantError <: Exception
    status::Int
    message::String
    detail::Any
    source::Union{HTTP.Exception, Nothing}
end
```

All API functions must catch HTTP exceptions and wrap them in QdrantError. Never return raw HTTP exceptions.

### 4. Type System with StructUtils.jl

Create Julia structs for all Qdrant API schemas using StructUtils annotations:
```julia
using StructUtils

@with_kw struct CollectionDescription
    name::String
end
StructUtils.@map CollectionDescription
```

Use `JSON.parse(T, str)` for typed deserialization and `JSON.json(x)` for serialization. Follow OpenAPI schemas exactly for field names, types, and optionality.

### 5. HTTP Client Layer

**Client struct:**
```julia
Base.@kwdef mutable struct Client
    host::String = "http://localhost"
    port::Int = 6333
    api_key::Union{String, Nothing} = nothing
    pool::Union{HTTP.Pool, Nothing} = nothing
end
```

**Global client pattern:**
```julia
const CLIENT = Ref{Client}()
set_global_client(client::Client)   # exported
get_global_client()                 # internal
```

**Request function:** `_request()` handles URL construction, authentication headers, HTTP requests with connection pooling, error wrapping, and JSON parsing.

### 6. Multiple Dispatch API Pattern

Every exported function supports two forms:
```julia
# Explicit client
create_collection(client::Client, name::String, params::CollectionParams)

# Default global client
create_collection(name::String, params::CollectionParams; client=get_global_client())
```

### 7. API Endpoint Coverage

**Priority 1 (Core):**
- Collections: create, list, get, update, delete, exists
- Points: upsert, retrieve, delete, scroll, count
- Search: search, recommend, query

**Priority 2 (Advanced):**
- Discovery: discover, recommend with context
- Service: health, metrics, telemetry
- Snapshots: create, list, delete, recover
- Distributed: cluster operations, shard management

### 8. Testing Strategy

**Unit tests (`test/unit/`):**
- Mock HTTP responses using HTTP.Response
- Test error handling, serialization, function dispatch
- Use `HTTP.mock()` for isolation

**Integration tests (`test/integration/`):**
- Require Docker Qdrant container
- Use `@skipif` if container not available
- Test real API calls

**Quality checks:**
- `Aqua.jl` for method ambiguities and undefined exports
- `JuliaFormatter.jl` (BlueStyle) for code formatting

### 9. Development Commands

Follow CLAUDE.md commands:
```bash
# Install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run tests
julia --project=. test/runtests.jl

# Quality check
julia --project=. -e 'using Aqua; Aqua.test_all(QdrantClient)'

# Format code
julia --project=. -e 'using JuliaFormatter; format(".")'

# Refresh API spec
curl -o openapi.json https://raw.githubusercontent.com/qdrant/qdrant/master/docs/redoc/master/openapi.json

# Local Qdrant for integration tests
docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

## Critical Files to Modify

1. `/home/ajaimes/Documents/GitHub/Julia/Packages/QdrantClient.jl/src/QdrantClient.jl` - Main module
2. `/home/ajaimes/Documents/GitHub/Julia/Packages/QdrantClient.jl/Project.toml` - Dependencies
3. `/home/ajaimes/Documents/GitHub/Julia/Packages/QdrantClient.jl/test/runtests.jl` - Test entry point
4. `/home/ajaimes/Documents/GitHub/Julia/Packages/QdrantClient.jl/docs/make.jl` - Documentation
5. `/home/ajaimes/Documents/GitHub/Julia/Packages/QdrantClient.jl/README.md` - Package description

## Verification

**End-to-end testing:**
1. Run `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
2. Run `julia --project=. test/runtests.jl` (unit tests should pass)
3. Start Docker Qdrant: `docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant`
4. Run integration tests (skip if Docker not available)
5. Run quality checks: `julia --project=. -e 'using Aqua; Aqua.test_all(QdrantClient)'`
6. Format code: `julia --project=. -e 'using JuliaFormatter; format(".")'`

**API verification:**
- Create a collection
- Insert points
- Search points
- Delete collection
All operations should succeed with proper error handling.

## Alternative Approaches Considered

1. **Incremental refactoring vs. rewrite**: Starting from scratch is preferred due to significant architectural changes needed.
2. **Code generation from OpenAPI**: Could auto-generate types and endpoints, but manual implementation ensures better Julia idioms and StructUtils integration.
3. **Different error handling strategies**: Must follow CLAUDE.md requirement of QdrantError wrapping all HTTP exceptions.