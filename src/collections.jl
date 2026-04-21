# ============================================================================
# Collections API
# ============================================================================

_collection_path(name::AbstractString) = "/collections/$name"
_collection_aliases_path(name::AbstractString) = "/collections/$name/aliases"

function _alias_action_body(action::AbstractString, payload::AbstractDict)
    return Dict{String, Any}("actions" => [Dict(action => Dict(payload))])
end

"""
    collections(client::Client)

List all collections.

# Returns
Dict with collections information.
"""
function collections(client::Client=get_global_client())
    response = _request(HTTP.get, client, "/collections")
    return _parse_response(response, Dict)
end

"""
    create_collection(client::Client, name::AbstractString, config::CollectionConfig)

Create a new collection.

# Arguments
- `client::Client`: The Qdrant client
- `name::AbstractString`: Collection name
- `config::CollectionConfig`: Collection configuration

# Returns
Dict with operation status
"""
function create_collection(
    client::Client,
    name::AbstractString,
    config::CollectionConfig
)
    response = _request(HTTP.put, client, _collection_path(name), QdrantClient._struct_to_dict(config))
    return _parse_response(response, Dict)
end

create_collection(name::AbstractString, config::CollectionConfig) =
    create_collection(get_global_client(), name, config)

create_collection(client::Client, name::AbstractString; kwargs...) =
    create_collection(client, name, CollectionConfig(; kwargs...))

create_collection(name::AbstractString; kwargs...) =
    create_collection(get_global_client(), name; kwargs...)

"""
    delete_collection(client::Client, name::String)

Delete a collection.

# Arguments
- `client::Client`: The Qdrant client
- `name::String`: Collection name

# Returns
Dict with operation status
"""
function delete_collection(client::Client, name::AbstractString)
    response = _request(HTTP.delete, client, _collection_path(name))
    return _parse_response(response, Dict)
end

delete_collection(name::AbstractString) = delete_collection(get_global_client(), name)

"""
    collection_exists(client::Client, name::String)

Check if a collection exists.

# Arguments
- `client::Client`: The Qdrant client
- `name::String`: Collection name

# Returns
Dict with existence information
"""
function collection_exists(client::Client, name::AbstractString)
    response = _request(HTTP.get, client, string(_collection_path(name), "/exists"))
    return _parse_response(response, Dict)
end

collection_exists(name::AbstractString) = collection_exists(get_global_client(), name)

"""
    get_collection_info(client::Client, name::String)

Get collection information.

# Arguments
- `client::Client`: The Qdrant client
- `name::String`: Collection name

# Returns
CollectionInfo object
"""
function get_collection_info(client::Client, name::AbstractString)
    response = _request(HTTP.get, client, _collection_path(name))
    return _parse_response(response, CollectionInfo)
end

get_collection_info(name::AbstractString) = get_collection_info(get_global_client(), name)

"""
    update_collection(client::Client, name::AbstractString, config::CollectionUpdate)

Update a collection.

# Arguments
- `client::Client`: The Qdrant client
- `name::AbstractString`: Collection name
- `config::CollectionUpdate`: Update configuration

# Returns
Dict with operation status
"""
function update_collection(
    client::Client,
    name::AbstractString,
    config::CollectionUpdate
)
    response = _request(HTTP.patch, client, _collection_path(name), QdrantClient._struct_to_dict(config))
    return _parse_response(response, Dict)
end

update_collection(name::AbstractString, config::CollectionUpdate) =
    update_collection(get_global_client(), name, config)

update_collection(client::Client, name::AbstractString; kwargs...) =
    update_collection(client, name, CollectionUpdate(; kwargs...))

update_collection(name::AbstractString; kwargs...) =
    update_collection(get_global_client(), name; kwargs...)

"""
    list_aliases(client::Client)

List all collection aliases.

# Arguments
- `client::Client`: The Qdrant client

# Returns
Dict with aliases information
"""
function list_aliases(client::Client=get_global_client())
    response = _request(HTTP.get, client, "/aliases")
    return _parse_response(response, Dict)
end

"""
    create_alias(client::Client, alias_name::String, collection_name::String)

Create a collection alias.

# Arguments
- `client::Client`: The Qdrant client
- `alias_name::String`: Alias name
- `collection_name::String`: Target collection name

# Returns
Dict with operation status
"""
function create_alias(
    client::Client,
    alias_name::AbstractString,
    collection_name::AbstractString
)
    body = _alias_action_body(
        "create_alias",
        Dict(
            "collection_name" => collection_name,
            "alias_name" => alias_name,
        ),
    )
    response = _request(HTTP.post, client, "/collections/aliases", body)
    return _parse_response(response, Dict)
end

create_alias(alias_name::AbstractString, collection_name::AbstractString) =
    create_alias(get_global_client(), alias_name, collection_name)

"""
    delete_alias(client::Client, alias_name::String)

Delete a collection alias.

# Arguments
- `client::Client`: The Qdrant client
- `alias_name::String`: Alias name

# Returns
Dict with operation status
"""
function delete_alias(client::Client, alias_name::AbstractString)
    body = _alias_action_body("delete_alias", Dict("alias_name" => alias_name))
    response = _request(HTTP.post, client, "/collections/aliases", body)
    return _parse_response(response, Dict)
end

delete_alias(alias_name::AbstractString) = delete_alias(get_global_client(), alias_name)

"""
    rename_alias(client::Client, old_alias::String, new_alias::String)

Rename a collection alias.

# Arguments
- `client::Client`: The Qdrant client
- `old_alias::String`: Old alias name
- `new_alias::String`: New alias name

# Returns
Dict with operation status
"""
function rename_alias(
    client::Client,
    old_alias::AbstractString,
    new_alias::AbstractString
)
    body = _alias_action_body(
        "rename_alias",
        Dict(
            "old_alias_name" => old_alias,
            "new_alias_name" => new_alias,
        ),
    )
    response = _request(HTTP.post, client, "/collections/aliases", body)
    return _parse_response(response, Dict)
end

rename_alias(old_alias::AbstractString, new_alias::AbstractString) =
    rename_alias(get_global_client(), old_alias, new_alias)

"""
    list_collection_aliases(client::Client, collection_name::String)

List aliases for a specific collection.

# Arguments
- `client::Client`: The Qdrant client
- `collection_name::String`: Collection name

# Returns
Dict with aliases for the collection
"""
function list_collection_aliases(client::Client, collection_name::AbstractString)
    response = _request(HTTP.get, client, _collection_aliases_path(collection_name))
    return _parse_response(response, Dict)
end

list_collection_aliases(collection_name::AbstractString) =
    list_collection_aliases(get_global_client(), collection_name)
