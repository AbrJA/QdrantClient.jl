# ============================================================================
# Collections API — HTTP transport
# ============================================================================

_collection_path(name::AbstractString) = "/collections/$name"

# ── List ─────────────────────────────────────────────────────────────────

"""
    list_collections(conn) -> QdrantResponse{Vector{CollectionDescription}}

List all collections on the server.
"""
function list_collections(conn::QdrantConnection{HTTPTransport})
    resp = http_request(HTTP.get, conn, "/collections")
    raw, status, time = _unwrap(resp)
    colls = raw isa AbstractDict ? get(raw, "collections", Any[]) : Any[]
    result = CollectionDescription[CollectionDescription(c["name"]) for c in colls]
    QdrantResponse(result, status, time)
end
list_collections() = list_collections(get_client())

# ── Create ───────────────────────────────────────────────────────────────

"""
    create_collection(conn, name, config) -> QdrantResponse{Bool}
    create_collection(conn, name; vectors, kwargs...) -> QdrantResponse{Bool}

Create a new collection.

# Examples
```julia
create_collection(conn, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
create_collection(conn, "demo"; vectors=VectorParams(size=4, distance=Dot))
```
"""
function create_collection(conn::QdrantConnection{HTTPTransport}, name::AbstractString,
                           config::CollectionConfig)
    parse_bool(http_request(HTTP.put, conn, _collection_path(name), config))
end
create_collection(name::AbstractString, config::CollectionConfig) =
    create_collection(get_client(), name, config)
create_collection(conn::QdrantConnection, name::AbstractString; kwargs...) =
    create_collection(conn, name, CollectionConfig(; kwargs...))
create_collection(name::AbstractString; kwargs...) =
    create_collection(get_client(), name; kwargs...)

# ── Delete ───────────────────────────────────────────────────────────────

"""
    delete_collection(conn, name) -> QdrantResponse{Bool}

Delete a collection.
"""
function delete_collection(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    parse_bool(http_request(HTTP.delete, conn, _collection_path(name)))
end
delete_collection(name::AbstractString) = delete_collection(get_client(), name)

# ── Exists ───────────────────────────────────────────────────────────────

"""
    collection_exists(conn, name) -> QdrantResponse{Bool}

Check if a collection exists.
"""
function collection_exists(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, _collection_path(name) * "/exists")
    raw, status, time = _unwrap(resp)
    exists = raw isa AbstractDict && get(raw, "exists", false) === true
    QdrantResponse(exists, status, time)
end
collection_exists(name::AbstractString) = collection_exists(get_client(), name)

# ── Get Info ─────────────────────────────────────────────────────────────

"""
    get_collection(conn, name) -> QdrantResponse{Dict{String,Any}}

Get detailed collection information.
"""
function get_collection(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, _collection_path(name))
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
get_collection(name::AbstractString) = get_collection(get_client(), name)

# ── Update ───────────────────────────────────────────────────────────────

"""
    update_collection(conn, name, config) -> QdrantResponse{Bool}
    update_collection(conn, name; kwargs...) -> QdrantResponse{Bool}

Update collection parameters.
"""
function update_collection(conn::QdrantConnection{HTTPTransport}, name::AbstractString,
                           config::CollectionUpdate)
    parse_bool(http_request(HTTP.patch, conn, _collection_path(name), config))
end
update_collection(name::AbstractString, config::CollectionUpdate) =
    update_collection(get_client(), name, config)
update_collection(conn::QdrantConnection, name::AbstractString; kwargs...) =
    update_collection(conn, name, CollectionUpdate(; kwargs...))
update_collection(name::AbstractString; kwargs...) =
    update_collection(get_client(), name; kwargs...)

# ── Optimization progress ───────────────────────────────────────────────

"""
    get_collection_optimizations(conn, name) -> QdrantResponse{Dict{String,Any}}

Get optimization progress for a collection.
"""
function get_collection_optimizations(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, _collection_path(name) * "/optimizations")
    raw, status, time = _unwrap(resp)
    QdrantResponse(raw isa AbstractDict ? raw : Dict{String,Any}(), status, time)
end
get_collection_optimizations(name::AbstractString) =
    get_collection_optimizations(get_client(), name)

# ============================================================================
# Aliases — HTTP
# ============================================================================

_alias_action(action::AbstractString, payload::AbstractDict) =
    Dict{String,Any}("actions" => [Dict(action => payload)])

"""
    list_aliases(conn) -> QdrantResponse{Vector{AliasDescription}}

List all aliases across collections.
"""
function list_aliases(conn::QdrantConnection{HTTPTransport})
    resp = http_request(HTTP.get, conn, "/aliases")
    raw, status, time = _unwrap(resp)
    aliases = raw isa AbstractDict ? get(raw, "aliases", Any[]) : Any[]
    result = AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in aliases]
    QdrantResponse(result, status, time)
end
list_aliases() = list_aliases(get_client())

"""
    list_collection_aliases(conn, collection) -> QdrantResponse{Vector{AliasDescription}}

List aliases for a specific collection.
"""
function list_collection_aliases(conn::QdrantConnection{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, conn, _collection_path(name) * "/aliases")
    raw, status, time = _unwrap(resp)
    aliases = raw isa AbstractDict ? get(raw, "aliases", Any[]) : Any[]
    result = AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in aliases]
    QdrantResponse(result, status, time)
end
list_collection_aliases(name::AbstractString) =
    list_collection_aliases(get_client(), name)

"""
    create_alias(conn, alias, collection) -> QdrantResponse{Bool}
"""
function create_alias(conn::QdrantConnection{HTTPTransport}, alias::AbstractString,
                      collection::AbstractString)
    body = _alias_action("create_alias",
        Dict("collection_name" => collection, "alias_name" => alias))
    parse_bool(http_request(HTTP.post, conn, "/collections/aliases", body))
end
create_alias(alias::AbstractString, collection::AbstractString) =
    create_alias(get_client(), alias, collection)

"""
    delete_alias(conn, alias) -> QdrantResponse{Bool}
"""
function delete_alias(conn::QdrantConnection{HTTPTransport}, alias::AbstractString)
    body = _alias_action("delete_alias", Dict("alias_name" => alias))
    parse_bool(http_request(HTTP.post, conn, "/collections/aliases", body))
end
delete_alias(alias::AbstractString) = delete_alias(get_client(), alias)

"""
    rename_alias(conn, old, new_name) -> QdrantResponse{Bool}
"""
function rename_alias(conn::QdrantConnection{HTTPTransport}, old::AbstractString,
                      new_name::AbstractString)
    body = _alias_action("rename_alias",
        Dict("old_alias_name" => old, "new_alias_name" => new_name))
    parse_bool(http_request(HTTP.post, conn, "/collections/aliases", body))
end
rename_alias(old::AbstractString, new_name::AbstractString) =
    rename_alias(get_client(), old, new_name)
