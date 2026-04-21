# CLAUDE.md — QdrantClient.jl Engineering Guide

## Development Commands
- **Instantiate**: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
- **Run Tests**: `julia --project=. test/runtests.jl`
- **Format Code**: `julia --project=. -e 'using JuliaFormatter; format(".")'`
- **Refresh API Spec**: `curl -o openapi.json https://raw.githubusercontent.com/qdrant/qdrant/master/docs/redoc/master/openapi.json`
- **Docker (Local Qdrant)**: `docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant`

## Core Technical Stack
- **Runtime**: Julia 1.12+ (Required for `Kaimon.jl` live REPL access).
- **Transport**: `HTTP.jl` (Utilizing global connection pooling).
- **Serialization**: `JSON.jl v1.0` (Modern standard; `JSON3.jl` is deprecated).
- **Type Mapping**: `StructUtils.jl` (Integrated with `JSON.jl` for zero-cost struct-to-JSON mapping).
- **Quality**: `Aqua.jl` (Automated QA) and `JuliaFormatter.jl` (BlueStyle compliance).

## Development Commands
- **Instantiate**: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
- **Run Tests**: `julia --project=. test/runtests.jl`
- **Quality Check**: `julia --project=. -e 'using Aqua; Aqua.test_all(QdrantClient)'`
- **Format Code**: `julia --project=. -e 'using JuliaFormatter; format(".")'`
- **Docker (Local Qdrant)**: `docker run -d -p 6333:6333 -p 6334:6334 qdrant/qdrant`

## Architecture & Conventions

### 1. Error Handling (Mandatory)
Never return raw HTTP exceptions. All API failures must be caught and wrapped in a `QdrantError`.
```julia
struct QdrantError <: Exception
    status::Int
    message::String
    detail::Any
    source::Union{HTTP.Exception, Nothing}
end

### 2. High-Performance JSON

Use JSON.json(x) for serialization and JSON.parse(T, str) for deserialization into typed structs.

Leverage StructUtils.jl to define JSON mappings without boilerplate.

### 3. Multiple Dispatch Design
- Implement API endpoints as overloaded functions of (client::Client, args...).
- Provide a default CLIENT Ref for convenience, but every exported function must support an explicit client keyword argument.
- Separate concerns: src/collections.jl, src/points.jl, src/search.jl, src/discovery.jl.

## Agent Configuration (MCP Servers)

- Memory (Engram): Stores architectural decisions and style preferences.
- Hands (Kaimon): Connects the agent to a live, stateful Julia REPL for testing and introspection.
- API Reference (Local Source of Truth):
    - File: openapi.json (root directory).
    - Instruction: Use the Filesystem MCP to read this file. Prioritize checking the components/schemas section when implementing new Julia structs to ensure exact field matching with the Qdrant API.

## Testing Strategy
- Unit: Mocked HTTP responses using HTTP.Response.
- Integration: Requires local Docker Qdrant. Check for server availability before running.
- Aqua: Mandatory check for method ambiguities and undefined exports.
