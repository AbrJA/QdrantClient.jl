# ============================================================================
# Collections API
# ============================================================================

collection_path(name::AbstractString) = "/collections/$name"

"""
    list_collections(client) -> Vector{CollectionDescription}

List all collections.
"""
function list_collections(c::QdrantConnection)
    is_grpc(c) && return list_collections(c, Val(:grpc))
    resp = request(HTTP.get, c, "/collections")
    r = parse_response(resp)
    r isa AbstractDict || return CollectionDescription[]
    colls = get(r, "collections", Any[])
    CollectionDescription[CollectionDescription(c_["name"]) for c_ in colls]
end
list_collections() = list_collections(get_client())

"""
    create_collection(client, name, config::CollectionConfig) -> Bool
    create_collection(client, name; vectors, kwargs...) -> Bool

Create a new collection.

# Examples
```julia
create_collection(client, "demo", CollectionConfig(vectors=VectorParams(size=4, distance=Dot)))
create_collection(client, "demo"; vectors=VectorParams(size=4, distance=Dot))
```
"""
function create_collection(c::QdrantConnection, name::AbstractString, config::CollectionConfig)
    is_grpc(c) && return create_collection(c, name, config, Val(:grpc))
    parse_bool(request(HTTP.put, c, collection_path(name), config))
end
create_collection(name::AbstractString, config::CollectionConfig) =
    create_collection(get_client(), name, config)
create_collection(c::QdrantConnection, name::AbstractString; kwargs...) =
    create_collection(c, name, CollectionConfig(; kwargs...))
create_collection(name::AbstractString; kwargs...) =
    create_collection(get_client(), name; kwargs...)

"""
    delete_collection(client, name) -> Bool

Delete a collection.
"""
function delete_collection(c::QdrantConnection, name::AbstractString)
    is_grpc(c) && return delete_collection(c, name, Val(:grpc))
    parse_bool(request(HTTP.delete, c, collection_path(name)))
end
delete_collection(name::AbstractString) = delete_collection(get_client(), name)

"""
    collection_exists(client, name) -> Bool

Check if a collection exists.
"""
function collection_exists(c::QdrantConnection, name::AbstractString)
    is_grpc(c) && return collection_exists(c, name, Val(:grpc))
    resp = request(HTTP.get, c, collection_path(name) * "/exists")
    r = parse_response(resp)
    r isa AbstractDict && get(r, "exists", false) === true
end
collection_exists(name::AbstractString) = collection_exists(get_client(), name)

"""
    get_collection(client, name) -> Dict{String,Any}

Get detailed collection information including status, config, and statistics.
"""
function get_collection(c::QdrantConnection, name::AbstractString)
    is_grpc(c) && return get_collection(c, name, Val(:grpc))
    resp = request(HTTP.get, c, collection_path(name))
    parse_response(resp)
end
get_collection(name::AbstractString) = get_collection(get_client(), name)

"""
    update_collection(client, name, config::CollectionUpdate) -> Bool
    update_collection(client, name; kwargs...) -> Bool

Update collection parameters.
"""
function update_collection(c::QdrantConnection, name::AbstractString, config::CollectionUpdate)
    is_grpc(c) && return update_collection(c, name, config, Val(:grpc))
    parse_bool(request(HTTP.patch, c, collection_path(name), config))
end
update_collection(name::AbstractString, config::CollectionUpdate) =
    update_collection(get_client(), name, config)
update_collection(c::QdrantConnection, name::AbstractString; kwargs...) =
    update_collection(c, name, CollectionUpdate(; kwargs...))
update_collection(name::AbstractString; kwargs...) =
    update_collection(get_client(), name; kwargs...)

"""
    get_collection_optimizations(client, name) -> Dict{String,Any}

Get optimization progress for a collection.
"""
function get_collection_optimizations(c::QdrantConnection, name::AbstractString)
    resp = request(HTTP.get, c, collection_path(name) * "/optimizations")
    parse_response(resp)
end
get_collection_optimizations(name::AbstractString) =
    get_collection_optimizations(get_client(), name)

# ── Aliases ──────────────────────────────────────────────────────────────

alias_action_body(action::AbstractString, payload::AbstractDict) =
    Dict{String,Any}("actions" => [Dict(action => payload)])

"""
    list_aliases(client) -> Vector{AliasDescription}

List all aliases across collections.
"""
function list_aliases(c::QdrantConnection)
    is_grpc(c) && return list_aliases(c, Val(:grpc))
    resp = request(HTTP.get, c, "/aliases")
    r = parse_response(resp)
    r isa AbstractDict || return AliasDescription[]
    raw = get(r, "aliases", Any[])
    AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in raw]
end
list_aliases() = list_aliases(get_client())

"""
    list_collection_aliases(client, collection) -> Vector{AliasDescription}

List aliases for a specific collection.
"""
function list_collection_aliases(c::QdrantConnection, name::AbstractString)
    is_grpc(c) && return list_collection_aliases(c, name, Val(:grpc))
    resp = request(HTTP.get, c, collection_path(name) * "/aliases")
    r = parse_response(resp)
    r isa AbstractDict || return AliasDescription[]
    raw = get(r, "aliases", Any[])
    AliasDescription[AliasDescription(a["alias_name"], a["collection_name"]) for a in raw]
end
list_collection_aliases(name::AbstractString) =
    list_collection_aliases(get_client(), name)

"""
    create_alias(client, alias, collection) -> Bool
"""
function create_alias(c::QdrantConnection, alias::AbstractString, collection::AbstractString)
    is_grpc(c) && return create_alias(c, alias, collection, Val(:grpc))
    body = alias_action_body("create_alias", Dict("collection_name" => collection, "alias_name" => alias))
    parse_bool(request(HTTP.post, c, "/collections/aliases", body))
end
create_alias(alias::AbstractString, collection::AbstractString) =
    create_alias(get_client(), alias, collection)

"""
    delete_alias(client, alias) -> Bool
"""
function delete_alias(c::QdrantConnection, alias::AbstractString)
    is_grpc(c) && return delete_alias(c, alias, Val(:grpc))
    body = alias_action_body("delete_alias", Dict("alias_name" => alias))
    parse_bool(request(HTTP.post, c, "/collections/aliases", body))
end
delete_alias(alias::AbstractString) = delete_alias(get_client(), alias)

"""
    rename_alias(client, old, new) -> Bool
"""
function rename_alias(c::QdrantConnection, old::AbstractString, new_name::AbstractString)
    is_grpc(c) && return rename_alias(c, old, new_name, Val(:grpc))
    body = alias_action_body("rename_alias", Dict("old_alias_name" => old, "new_alias_name" => new_name))
    parse_bool(request(HTTP.post, c, "/collections/aliases", body))
end
rename_alias(old::AbstractString, new_name::AbstractString) =
    rename_alias(get_client(), old, new_name)
