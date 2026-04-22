# ============================================================================
# gRPC Collections API — dispatch on GRPCTransport
# ============================================================================

# ── List Collections ─────────────────────────────────────────────────────

function list_collections(c::QdrantConnection, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    resp = grpc_request(transport, Collections_List_Client, qdrant.ListCollectionsRequest())
    CollectionDescription[CollectionDescription(cd.name) for cd in resp.collections]
end

# ── Create Collection ────────────────────────────────────────────────────

function create_collection(c::QdrantConnection, name::AbstractString,
                           config::CollectionConfig, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.CreateCollection(
        name,                                          # collection_name
        to_proto_hnsw_config(config.hnsw_config),      # hnsw_config
        to_proto_wal_config(config.wal_config),        # wal_config
        to_proto_optimizers_config(config.optimizers_config), # optimizers_config
        config.shard_number !== nothing ? UInt32(config.shard_number) : UInt32(0),
        config.on_disk_payload !== nothing ? config.on_disk_payload : false,
        UInt64(0),                                     # timeout
        to_proto_vectors_config(config.vectors),       # vectors_config
        config.replication_factor !== nothing ? UInt32(config.replication_factor) : UInt32(0),
        config.write_consistency_factor !== nothing ? UInt32(config.write_consistency_factor) : UInt32(0),
        nothing,                                       # quantization_config
        config.sharding_method !== nothing ? (
            config.sharding_method == "custom" ? qdrant.var"ShardingMethod".Custom :
            qdrant.var"ShardingMethod".Auto
        ) : qdrant.var"ShardingMethod".Auto,
        nothing,                                       # sparse_vectors_config
        nothing,                                       # strict_mode_config
        Dict{String,qdrant.Value}(),                   # metadata
    )
    resp = grpc_request(transport, Collections_Create_Client, req)
    resp.result
end

# ── Delete Collection ────────────────────────────────────────────────────

function delete_collection(c::QdrantConnection, name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.DeleteCollection(name, UInt64(0))
    resp = grpc_request(transport, Collections_Delete_Client, req)
    resp.result
end

# ── Collection Exists ────────────────────────────────────────────────────

function collection_exists(c::QdrantConnection, name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.CollectionExistsRequest(name)
    resp = grpc_request(transport, Collections_CollectionExists_Client, req)
    resp.result !== nothing ? resp.result.exists : false
end

# ── Get Collection ───────────────────────────────────────────────────────

function get_collection(c::QdrantConnection, name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.GetCollectionInfoRequest(name)
    resp = grpc_request(transport, Collections_Get_Client, req)
    _collection_info_to_dict(resp.result)
end

function _collection_info_to_dict(info::qdrant.CollectionInfo)
    result = Dict{String,Any}(
        "status" => string(info.status),
        "segments_count" => Int(info.segments_count),
        "points_count" => Int(info.points_count),
        "indexed_vectors_count" => Int(info.indexed_vectors_count),
    )
    if info.config !== nothing
        result["config"] = _collection_config_to_dict(info.config)
    end
    result
end

function _collection_config_to_dict(config::qdrant.CollectionConfig)
    result = Dict{String,Any}()
    if config.params !== nothing
        params = config.params
        result["params"] = Dict{String,Any}(
            "shard_number" => Int(params.shard_number),
            "on_disk_payload" => params.on_disk_payload,
        )
    end
    result
end

# ── Update Collection ────────────────────────────────────────────────────

function update_collection(c::QdrantConnection, name::AbstractString,
                           config::CollectionUpdate, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.UpdateCollection(
        name,
        to_proto_optimizers_config(config.optimizers_config),
        UInt64(0),
        nothing,
        to_proto_hnsw_config(config.hnsw_config),
        nothing,
        nothing,
        nothing,
        nothing,
        Dict{String,qdrant.Value}(),
    )
    resp = grpc_request(transport, Collections_Update_Client, req)
    resp.result
end

# ── Aliases ──────────────────────────────────────────────────────────────

function list_aliases(c::QdrantConnection, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    resp = grpc_request(transport, Collections_ListAliases_Client, qdrant.ListAliasesRequest())
    AliasDescription[AliasDescription(a.alias_name, a.collection_name) for a in resp.aliases]
end

function list_collection_aliases(c::QdrantConnection, name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.ListCollectionAliasesRequest(name)
    resp = grpc_request(transport, Collections_ListCollectionAliases_Client, req)
    AliasDescription[AliasDescription(a.alias_name, a.collection_name) for a in resp.aliases]
end

function create_alias(c::QdrantConnection, alias::AbstractString,
                      collection::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    action = qdrant.AliasOperations(OneOf(:create_alias,
        qdrant.CreateAlias(collection, alias)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(transport, Collections_UpdateAliases_Client, req)
    resp.result
end

function delete_alias(c::QdrantConnection, alias::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    action = qdrant.AliasOperations(OneOf(:delete_alias,
        qdrant.DeleteAlias(alias)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(transport, Collections_UpdateAliases_Client, req)
    resp.result
end

function rename_alias(c::QdrantConnection, old::AbstractString,
                      new_name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    action = qdrant.AliasOperations(OneOf(:rename_alias,
        qdrant.RenameAlias(old, new_name)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(transport, Collections_UpdateAliases_Client, req)
    resp.result
end
