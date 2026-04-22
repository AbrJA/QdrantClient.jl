# ============================================================================
# Collections API — gRPC transport
# ============================================================================

function list_collections(client::QdrantClient{GRPCTransport})
    resp = grpc_request(client.transport, Collections_List_Client, qdrant.ListCollectionsRequest())
    result = CollectionDescription[CollectionDescription(cd.name) for cd in resp.collections]
    QdrantResponse(result, "ok", 0.0)
end

function create_collection(client::QdrantClient{GRPCTransport}, name::AbstractString,
                           config::CollectionConfig)
    req = qdrant.CreateCollection(
        name,
        to_proto_hnsw_config(config.hnsw_config),
        to_proto_wal_config(config.wal_config),
        to_proto_optimizers_config(config.optimizers_config),
        config.shard_number !== nothing ? UInt32(config.shard_number) : UInt32(0),
        config.on_disk_payload !== nothing ? config.on_disk_payload : false,
        UInt64(0),
        to_proto_vectors_config(config.vectors),
        config.replication_factor !== nothing ? UInt32(config.replication_factor) : UInt32(0),
        config.write_consistency_factor !== nothing ? UInt32(config.write_consistency_factor) : UInt32(0),
        nothing,
        config.sharding_method !== nothing ? (
            config.sharding_method == "custom" ? qdrant.var"ShardingMethod".Custom :
            qdrant.var"ShardingMethod".Auto
        ) : qdrant.var"ShardingMethod".Auto,
        nothing, nothing,
        Dict{String,qdrant.Value}(),
    )
    resp = grpc_request(client.transport, Collections_Create_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end

function delete_collection(client::QdrantClient{GRPCTransport}, name::AbstractString)
    req = qdrant.DeleteCollection(name, UInt64(0))
    resp = grpc_request(client.transport, Collections_Delete_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end

function collection_exists(client::QdrantClient{GRPCTransport}, name::AbstractString)
    req = qdrant.CollectionExistsRequest(name)
    resp = grpc_request(client.transport, Collections_CollectionExists_Client, req)
    exists = resp.result !== nothing ? resp.result.exists : false
    QdrantResponse(exists, "ok", 0.0)
end

function get_collection(client::QdrantClient{GRPCTransport}, name::AbstractString)
    req = qdrant.GetCollectionInfoRequest(name)
    resp = grpc_request(client.transport, Collections_Get_Client, req)
    QdrantResponse(_collection_info_to_dict(resp.result), "ok", 0.0)
end

function _collection_info_to_dict(info::qdrant.CollectionInfo)
    result = Dict{String,Any}(
        "status"                => string(info.status),
        "segments_count"        => Int(info.segments_count),
        "points_count"          => Int(info.points_count),
        "indexed_vectors_count" => Int(info.indexed_vectors_count),
    )
    info.config !== nothing && (result["config"] = _collection_config_to_dict(info.config))
    result
end

function _collection_config_to_dict(config::qdrant.CollectionConfig)
    result = Dict{String,Any}()
    if config.params !== nothing
        p = config.params
        result["params"] = Dict{String,Any}(
            "shard_number"     => Int(p.shard_number),
            "on_disk_payload"  => p.on_disk_payload,
        )
    end
    result
end

function update_collection(client::QdrantClient{GRPCTransport}, name::AbstractString,
                           config::CollectionUpdate)
    req = qdrant.UpdateCollection(
        name,
        to_proto_optimizers_config(config.optimizers_config),
        UInt64(0),
        nothing,
        to_proto_hnsw_config(config.hnsw_config),
        nothing, nothing, nothing, nothing,
        Dict{String,qdrant.Value}(),
    )
    resp = grpc_request(client.transport, Collections_Update_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end

# ── Aliases — gRPC ───────────────────────────────────────────────────────

function list_aliases(client::QdrantClient{GRPCTransport})
    resp = grpc_request(client.transport, Collections_ListAliases_Client, qdrant.ListAliasesRequest())
    result = AliasDescription[AliasDescription(a.alias_name, a.collection_name) for a in resp.aliases]
    QdrantResponse(result, "ok", 0.0)
end

function list_collection_aliases(client::QdrantClient{GRPCTransport}, name::AbstractString)
    req = qdrant.ListCollectionAliasesRequest(name)
    resp = grpc_request(client.transport, Collections_ListCollectionAliases_Client, req)
    result = AliasDescription[AliasDescription(a.alias_name, a.collection_name) for a in resp.aliases]
    QdrantResponse(result, "ok", 0.0)
end

function create_alias(client::QdrantClient{GRPCTransport}, alias::AbstractString,
                      collection::AbstractString)
    action = qdrant.AliasOperations(OneOf(:create_alias,
        qdrant.CreateAlias(collection, alias)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(client.transport, Collections_UpdateAliases_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end

function delete_alias(client::QdrantClient{GRPCTransport}, alias::AbstractString)
    action = qdrant.AliasOperations(OneOf(:delete_alias,
        qdrant.DeleteAlias(alias)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(client.transport, Collections_UpdateAliases_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end

function rename_alias(client::QdrantClient{GRPCTransport}, old::AbstractString,
                      new_name::AbstractString)
    action = qdrant.AliasOperations(OneOf(:rename_alias,
        qdrant.RenameAlias(old, new_name)))
    req = qdrant.ChangeAliases([action], UInt64(0))
    resp = grpc_request(client.transport, Collections_UpdateAliases_Client, req)
    QdrantResponse(resp.result, "ok", 0.0)
end
