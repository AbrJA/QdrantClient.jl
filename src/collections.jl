# ============================================================================
# Collections API — HTTP transport
# ============================================================================

_collection_path(name::AbstractString) = "/collections/$name"

# ── List ─────────────────────────────────────────────────────────────────

"""
    list_collections(client) -> QdrantResponse{Vector{CollectionDescription}}

List all collections on the server.
"""
function list_collections(client::QdrantClient{HTTPTransport})
    resp = http_request(HTTP.get, client, "/collections")
    raw, status, time = _unwrap(resp)
    colls = raw isa AbstractDict ? get(raw, "collections", Any[]) : Any[]
    result = CollectionDescription[CollectionDescription(c["name"]) for c in colls]
    QdrantResponse(result, status, time)
end
list_collections() = list_collections(get_client())

# ── Create ───────────────────────────────────────────────────────────────

"""
    create_collection(client, name, config) -> QdrantResponse{Bool}
    create_collection(client, name; vectors, kwargs...) -> QdrantResponse{Bool}

Create a new collection.

# Examples
```julia
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
create_collection(client, "demo"; vectors=VectorParams(size=4, distance=Dot))
```
"""
function create_collection(client::QdrantClient{HTTPTransport}, name::AbstractString,
                           config::CollectionConfig; timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.put, client, _collection_path(name), config;
                            query=_timeout_query(timeout)))
end
create_collection(name::AbstractString, config::CollectionConfig; kwargs...) =
    create_collection(get_client(), name, config; kwargs...)
function create_collection(client::QdrantClient, name::AbstractString;
                           timeout::Optional{Int}=nothing, kwargs...)
    create_collection(client, name, CollectionConfig(; kwargs...); timeout=timeout)
end
create_collection(name::AbstractString; kwargs...) =
    create_collection(get_client(), name; kwargs...)

# ── Delete ───────────────────────────────────────────────────────────────

"""
    delete_collection(client, name) -> QdrantResponse{Bool}

Delete a collection.
"""
function delete_collection(client::QdrantClient{HTTPTransport}, name::AbstractString;
                           timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.delete, client, _collection_path(name);
                            query=_timeout_query(timeout)))
end
delete_collection(name::AbstractString; kwargs...) = delete_collection(get_client(), name; kwargs...)

# ── Exists ───────────────────────────────────────────────────────────────

"""
    collection_exists(client, name) -> QdrantResponse{Bool}

Check if a collection exists.
"""
function collection_exists(client::QdrantClient{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, client, _collection_path(name) * "/exists")
    raw, status, time = _unwrap(resp)
    exists = raw isa AbstractDict && get(raw, "exists", false) === true
    QdrantResponse(exists, status, time)
end
collection_exists(name::AbstractString) = collection_exists(get_client(), name)

# ── Get Info ─────────────────────────────────────────────────────────────

"""
    get_collection(client, name) -> QdrantResponse{CollectionInfo}

Get detailed collection information.
"""
function get_collection(client::QdrantClient{HTTPTransport}, name::AbstractString)
    parse_collection_info(http_request(HTTP.get, client, _collection_path(name)))
end
get_collection(name::AbstractString) = get_collection(get_client(), name)

# ── Update ───────────────────────────────────────────────────────────────

"""
    update_collection(client, name, config) -> QdrantResponse{Bool}
    update_collection(client, name; kwargs...) -> QdrantResponse{Bool}

Update collection parameters.
"""
function update_collection(client::QdrantClient{HTTPTransport}, name::AbstractString,
                           config::CollectionUpdate; timeout::Optional{Int}=nothing)
    parse_bool(http_request(HTTP.patch, client, _collection_path(name), config;
                            query=_timeout_query(timeout)))
end
update_collection(name::AbstractString, config::CollectionUpdate; kwargs...) =
    update_collection(get_client(), name, config; kwargs...)
function update_collection(client::QdrantClient, name::AbstractString;
                           timeout::Optional{Int}=nothing, kwargs...)
    update_collection(client, name, CollectionUpdate(; kwargs...); timeout=timeout)
end
update_collection(name::AbstractString; kwargs...) =
    update_collection(get_client(), name; kwargs...)

# ── Optimization progress ───────────────────────────────────────────────

"""
    get_collection_optimizations(client, name) -> QdrantResponse{OptimizationsStatus}

Get optimization progress for a collection.
"""
function get_collection_optimizations(client::QdrantClient{HTTPTransport}, name::AbstractString)
    parse_optimizations_status(http_request(HTTP.get, client, _collection_path(name) * "/optimizations"))
end
get_collection_optimizations(name::AbstractString) =
    get_collection_optimizations(get_client(), name)

# ============================================================================
# Aliases — HTTP
# ============================================================================

_alias_action(action::AbstractString, payload::AbstractDict) =
    Dict{String,Any}("actions" => [Dict(action => payload)])

"""
    list_aliases(client) -> QdrantResponse{Vector{AliasDescription}}

List all aliases across collections.
"""
function list_aliases(client::QdrantClient{HTTPTransport})
    resp = http_request(HTTP.get, client, "/aliases")
    raw, status, time = _unwrap(resp)
    aliases = raw isa AbstractDict ? get(raw, "aliases", Any[]) : Any[]
    result = AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in aliases]
    QdrantResponse(result, status, time)
end
list_aliases() = list_aliases(get_client())

"""
    list_collection_aliases(client, collection) -> QdrantResponse{Vector{AliasDescription}}

List aliases for a specific collection.
"""
function list_collection_aliases(client::QdrantClient{HTTPTransport}, name::AbstractString)
    resp = http_request(HTTP.get, client, _collection_path(name) * "/aliases")
    raw, status, time = _unwrap(resp)
    aliases = raw isa AbstractDict ? get(raw, "aliases", Any[]) : Any[]
    result = AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in aliases]
    QdrantResponse(result, status, time)
end
list_collection_aliases(name::AbstractString) =
    list_collection_aliases(get_client(), name)

"""
    create_alias(client, alias, collection) -> QdrantResponse{Bool}
"""
function create_alias(client::QdrantClient{HTTPTransport}, alias::AbstractString,
                      collection::AbstractString; timeout::Optional{Int}=nothing)
    body = _alias_action("create_alias",
        Dict("collection_name" => collection, "alias_name" => alias))
    parse_bool(http_request(HTTP.post, client, "/collections/aliases", body;
                            query=_timeout_query(timeout)))
end
create_alias(alias::AbstractString, collection::AbstractString; kwargs...) =
    create_alias(get_client(), alias, collection; kwargs...)

"""
    delete_alias(client, alias) -> QdrantResponse{Bool}
"""
function delete_alias(client::QdrantClient{HTTPTransport}, alias::AbstractString;
                      timeout::Optional{Int}=nothing)
    body = _alias_action("delete_alias", Dict("alias_name" => alias))
    parse_bool(http_request(HTTP.post, client, "/collections/aliases", body;
                            query=_timeout_query(timeout)))
end
delete_alias(alias::AbstractString; kwargs...) = delete_alias(get_client(), alias; kwargs...)

"""
    rename_alias(client, old, new_name) -> QdrantResponse{Bool}
"""
function rename_alias(client::QdrantClient{HTTPTransport}, old::AbstractString,
                      new_name::AbstractString; timeout::Optional{Int}=nothing)
    body = _alias_action("rename_alias",
        Dict("old_alias_name" => old, "new_alias_name" => new_name))
    parse_bool(http_request(HTTP.post, client, "/collections/aliases", body;
                            query=_timeout_query(timeout)))
end
rename_alias(old::AbstractString, new_name::AbstractString; kwargs...) =
    rename_alias(get_client(), old, new_name; kwargs...)
