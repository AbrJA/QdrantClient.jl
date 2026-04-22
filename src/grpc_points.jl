# ============================================================================
# gRPC Points API — dispatch on GRPCTransport
# ============================================================================

# ── Upsert Points ────────────────────────────────────────────────────────

function upsert_points(c::QdrantConnection, collection::AbstractString,
                       points::AbstractVector{<:Point}, ::Val{:grpc};
                       wait::Bool=true, ordering::AbstractString="weak")
    transport = c.transport::GRPCTransport
    proto_points = qdrant.PointStruct[to_proto_point(p) for p in points]
    req = qdrant.UpsertPoints(
        collection, wait, proto_points,
        to_proto_ordering(ordering),
        nothing, nothing, UInt64(0),
        qdrant.UpdateMode.Upsert,
    )
    resp = grpc_request(transport, Points_Upsert_Client, req)
    _grpc_update_response(resp)
end

function _grpc_update_response(resp::qdrant.PointsOperationResponse)
    status = resp.result !== nothing ? string(resp.result.status) : "completed"
    # Normalize gRPC status enum to match HTTP
    normalized = contains(lowercase(status), "completed") ? "completed" :
                 contains(lowercase(status), "acknowledged") ? "acknowledged" : status
    UpdateResponse(0, normalized)
end

# ── Delete Points ────────────────────────────────────────────────────────

function delete_points(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                       ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeletePoints(
        collection, wait,
        to_proto_points_selector(selector),
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_Delete_Client, req)
    _grpc_update_response(resp)
end

# ── Get Points ───────────────────────────────────────────────────────────

function get_points(c::QdrantConnection, collection::AbstractString,
                    ids::AbstractVector{<:PointId}, ::Val{:grpc};
                    with_vectors::Bool=false, with_payload::Bool=true)
    transport = c.transport::GRPCTransport
    proto_ids = qdrant.PointId[to_proto_point_id(id) for id in ids]
    req = qdrant.GetPoints(
        collection, proto_ids,
        to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_Get_Client, req)
    Record[_grpc_to_record(rp) for rp in resp.result]
end

function _grpc_to_record(rp::qdrant.RetrievedPoint)
    Record(
        from_proto_point_id(rp.id),
        isempty(rp.payload) ? nothing : from_proto_payload(rp.payload),
        from_proto_vectors(rp.vectors),
    )
end

# ── Set Payload ──────────────────────────────────────────────────────────

function set_payload(c::QdrantConnection, collection::AbstractString,
                     payload::AbstractDict,
                     selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                     ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.SetPayloadPoints(
        collection, wait, to_proto_payload(payload),
        ps, nothing, nothing, "", UInt64(0),
    )
    resp = grpc_request(transport, Points_SetPayload_Client, req)
    _grpc_update_response(resp)
end

# ── Overwrite Payload ────────────────────────────────────────────────────

function overwrite_payload(c::QdrantConnection, collection::AbstractString,
                           payload::AbstractDict,
                           selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                           ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.SetPayloadPoints(
        collection, wait, to_proto_payload(payload),
        ps, nothing, nothing, "", UInt64(0),
    )
    resp = grpc_request(transport, Points_OverwritePayload_Client, req)
    _grpc_update_response(resp)
end

# ── Delete Payload ───────────────────────────────────────────────────────

function delete_payload(c::QdrantConnection, collection::AbstractString,
                        keys::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                        ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.DeletePayloadPoints(
        collection, wait, String.(keys),
        ps, nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_DeletePayload_Client, req)
    _grpc_update_response(resp)
end

# ── Clear Payload ────────────────────────────────────────────────────────

function clear_payload(c::QdrantConnection, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                       ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.ClearPayloadPoints(
        collection, wait,
        to_proto_points_selector(selector),
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_ClearPayload_Client, req)
    _grpc_update_response(resp)
end

# ── Update Vectors ───────────────────────────────────────────────────────

function update_vectors(c::QdrantConnection, collection::AbstractString,
                        points::AbstractVector, ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    proto_points = qdrant.PointVectors[]
    for p in points
        id = to_proto_point_id(p isa AbstractDict ? p["id"] : p.id)
        vec = p isa AbstractDict ? p["vector"] : p.vector
        push!(proto_points, qdrant.PointVectors(id, to_proto_vectors(vec)))
    end
    req = qdrant.UpdatePointVectors(
        collection, wait, proto_points,
        nothing, nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_UpdateVectors_Client, req)
    _grpc_update_response(resp)
end

# ── Delete Vectors ───────────────────────────────────────────────────────

function delete_vectors(c::QdrantConnection, collection::AbstractString,
                        names::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter},
                        ::Val{:grpc}; wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeletePointVectors(
        collection, wait,
        to_proto_points_selector(selector),
        qdrant.VectorsSelector(String.(names)),
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_DeleteVectors_Client, req)
    _grpc_update_response(resp)
end

# ── Scroll Points ────────────────────────────────────────────────────────

function scroll_points(c::QdrantConnection, collection::AbstractString,
                       ::Val{:grpc};
                       filter::Optional{Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    transport = c.transport::GRPCTransport
    proto_offset = nothing
    if offset !== nothing
        proto_offset = to_proto_point_id(offset isa PointId ? offset : Int(offset))
    end
    req = qdrant.ScrollPoints(
        collection, to_proto_filter(filter), proto_offset,
        UInt32(limit), to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing, nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_Scroll_Client, req)
    points = Record[_grpc_to_record(rp) for rp in resp.result]
    npo = resp.next_page_offset !== nothing ? from_proto_point_id(resp.next_page_offset) : nothing
    ScrollResponse(points, npo)
end

# ── Count Points ─────────────────────────────────────────────────────────

function count_points(c::QdrantConnection, collection::AbstractString,
                      ::Val{:grpc};
                      filter::Optional{Filter}=nothing, exact::Bool=false)
    transport = c.transport::GRPCTransport
    req = qdrant.CountPoints(
        collection, to_proto_filter(filter), exact,
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_Count_Client, req)
    CountResponse(Int(resp.result.count))
end

# ── Create Field Index ───────────────────────────────────────────────────

function create_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString, ::Val{:grpc};
                              field_schema::Union{String, AbstractQdrantType, AbstractDict, Nothing}=nothing,
                              wait::Bool=true)
    transport = c.transport::GRPCTransport
    field_type = qdrant.FieldType.FieldTypeKeyword
    field_index_params = nothing
    if field_schema isa String
        ft = _string_to_field_type(field_schema)
        ft !== nothing && (field_type = ft)
    elseif field_schema isa TextIndexParams
        field_type = qdrant.var"FieldType".FieldTypeText
        field_index_params = qdrant.PayloadIndexParams(OneOf(:text_index_params,
            qdrant.TextIndexParams(
                field_schema.tokenizer !== nothing ? _string_to_tokenizer(field_schema.tokenizer) :
                    qdrant.var"TokenizerType".Whitespace,
                field_schema.lowercase !== nothing ? field_schema.lowercase : false,
                field_schema.min_token_len !== nothing ? UInt64(field_schema.min_token_len) : UInt64(0),
                field_schema.max_token_len !== nothing ? UInt64(field_schema.max_token_len) : UInt64(0),
                false, nothing, false, nothing, false, false,
            )))
    end
    req = qdrant.CreateFieldIndexCollection(
        collection, wait, field_name, field_type,
        field_index_params, nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_CreateFieldIndex_Client, req)
    _grpc_update_response(resp)
end

function _string_to_field_type(s::AbstractString)
    s == "keyword" && return qdrant.var"FieldType".FieldTypeKeyword
    s == "integer" && return qdrant.var"FieldType".FieldTypeInteger
    s == "float"   && return qdrant.var"FieldType".FieldTypeFloat
    s == "geo"     && return qdrant.var"FieldType".FieldTypeGeo
    s == "text"    && return qdrant.var"FieldType".FieldTypeText
    s == "bool"    && return qdrant.var"FieldType".FieldTypeBool
    s == "datetime" && return qdrant.var"FieldType".FieldTypeDatetime
    s == "uuid"    && return qdrant.var"FieldType".FieldTypeUuid
    nothing
end

function _string_to_tokenizer(s::AbstractString)
    s == "word"         && return qdrant.var"TokenizerType".Word
    s == "whitespace"   && return qdrant.var"TokenizerType".Whitespace
    s == "prefix"       && return qdrant.var"TokenizerType".Prefix
    s == "multilingual" && return qdrant.var"TokenizerType".Multilingual
    qdrant.var"TokenizerType".Whitespace
end

# ── Delete Field Index ───────────────────────────────────────────────────

function delete_payload_index(c::QdrantConnection, collection::AbstractString,
                              field_name::AbstractString, ::Val{:grpc};
                              wait::Bool=true)
    transport = c.transport::GRPCTransport
    req = qdrant.DeleteFieldIndexCollection(
        collection, wait, field_name,
        nothing, UInt64(0),
    )
    resp = grpc_request(transport, Points_DeleteFieldIndex_Client, req)
    _grpc_update_response(resp)
end
