# ============================================================================
# Points API — gRPC transport
# ============================================================================

# ── Helpers ──────────────────────────────────────────────────────────────

function _grpc_update(resp::qdrant.PointsOperationResponse)::QdrantResponse{UpdateResult}
    raw_status = resp.result !== nothing ? string(resp.result.status) : "completed"
    normalized = contains(lowercase(raw_status), "completed")    ? "completed"    :
                 contains(lowercase(raw_status), "acknowledged") ? "acknowledged" : raw_status
    QdrantResponse(UpdateResult(0, normalized), "ok", resp.time)
end

function _grpc_to_record(rp::qdrant.RetrievedPoint)::Record
    Record(
        from_proto_point_id(rp.id),
        isempty(rp.payload) ? Dict{String,Any}() : from_proto_payload(rp.payload),
        from_proto_vectors(rp.vectors),
    )
end

function _grpc_to_scored(sp::qdrant.ScoredPoint)::ScoredPoint
    ScoredPoint(
        from_proto_point_id(sp.id),
        Int(sp.version),
        Float64(sp.score),
        isempty(sp.payload) ? nothing : from_proto_payload(sp.payload),
        from_proto_vectors(sp.vectors),
    )
end

# ── Upsert ───────────────────────────────────────────────────────────────

function upsert_points(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                       points::AbstractVector{<:Point};
                       wait::Bool=true, ordering::AbstractString="weak")
    proto_points = qdrant.PointStruct[to_proto_point(p) for p in points]
    req = qdrant.UpsertPoints(
        collection, wait, proto_points,
        to_proto_ordering(ordering),
        nothing, nothing, UInt64(0),
        qdrant.UpdateMode.Upsert,
    )
    _grpc_update(grpc_request(client.transport, Points_Upsert_Client, req))
end

# ── Delete ───────────────────────────────────────────────────────────────

function delete_points(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    req = qdrant.DeletePoints(
        collection, wait,
        to_proto_points_selector(selector),
        nothing, nothing, UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_Delete_Client, req))
end

# ── Get ──────────────────────────────────────────────────────────────────

function get_points(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                    ids::AbstractVector{<:PointId};
                    with_vectors::Bool=false, with_payload::Bool=true)
    proto_ids = qdrant.PointId[to_proto_point_id(id) for id in ids]
    req = qdrant.GetPoints(
        collection, proto_ids,
        to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(client.transport, Points_Get_Client, req)
    records = Record[_grpc_to_record(rp) for rp in resp.result]
    QdrantResponse(records, "ok", resp.time)
end

# ── Set Payload ──────────────────────────────────────────────────────────

function set_payload(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                     payload::AbstractDict,
                     selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                     wait::Bool=true)
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.SetPayloadPoints(
        collection, wait, to_proto_payload(payload),
        ps, nothing, nothing, "", UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_SetPayload_Client, req))
end

# ── Overwrite Payload ────────────────────────────────────────────────────

function overwrite_payload(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                           payload::AbstractDict,
                           selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                           wait::Bool=true)
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.SetPayloadPoints(
        collection, wait, to_proto_payload(payload),
        ps, nothing, nothing, "", UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_OverwritePayload_Client, req))
end

# ── Delete Payload ───────────────────────────────────────────────────────

function delete_payload(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                        keys::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    ps = selector isa PointId ? to_proto_points_selector([selector]) : to_proto_points_selector(selector)
    req = qdrant.DeletePayloadPoints(
        collection, wait, String.(keys),
        ps, nothing, nothing, UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_DeletePayload_Client, req))
end

# ── Clear Payload ────────────────────────────────────────────────────────

function clear_payload(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                       selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                       wait::Bool=true)
    req = qdrant.ClearPayloadPoints(
        collection, wait,
        to_proto_points_selector(selector),
        nothing, nothing, UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_ClearPayload_Client, req))
end

# ── Update Vectors ───────────────────────────────────────────────────────

function update_vectors(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                        points::AbstractVector; wait::Bool=true)
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
    _grpc_update(grpc_request(client.transport, Points_UpdateVectors_Client, req))
end

# ── Delete Vectors ───────────────────────────────────────────────────────

function delete_vectors(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                        names::AbstractVector{<:AbstractString},
                        selector::Union{AbstractVector{<:PointId}, PointId, Filter};
                        wait::Bool=true)
    req = qdrant.DeletePointVectors(
        collection, wait,
        to_proto_points_selector(selector),
        qdrant.VectorsSelector(String.(names)),
        nothing, nothing, UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_DeleteVectors_Client, req))
end

# ── Scroll ───────────────────────────────────────────────────────────────

function scroll_points(client::QdrantClient{GRPCTransport}, collection::AbstractString;
                       filter::Optional{Filter}=nothing,
                       limit::Int=10, offset=nothing,
                       with_vectors::Bool=false, with_payload::Bool=true)
    proto_offset = offset !== nothing ?
        to_proto_point_id(offset isa PointId ? offset : Int(offset)) : nothing
    req = qdrant.ScrollPoints(
        collection, to_proto_filter(filter), proto_offset,
        UInt32(limit), to_proto_with_payload(with_payload),
        to_proto_with_vectors(with_vectors),
        nothing, nothing, nothing, UInt64(0),
    )
    resp = grpc_request(client.transport, Points_Scroll_Client, req)
    points = Record[_grpc_to_record(rp) for rp in resp.result]
    npo = resp.next_page_offset !== nothing ? from_proto_point_id(resp.next_page_offset) : nothing
    QdrantResponse(ScrollResult(points, npo), "ok", resp.time)
end

# ── Count ────────────────────────────────────────────────────────────────

function count_points(client::QdrantClient{GRPCTransport}, collection::AbstractString;
                      filter::Optional{Filter}=nothing, exact::Bool=false)
    req = qdrant.CountPoints(
        collection, to_proto_filter(filter), exact,
        nothing, nothing, UInt64(0),
    )
    resp = grpc_request(client.transport, Points_Count_Client, req)
    QdrantResponse(CountResult(Int(resp.result.count)), "ok", resp.time)
end

# ── Create Field Index ───────────────────────────────────────────────────

function create_payload_index(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                              field_name::AbstractString;
                              field_schema::Union{String, AbstractQdrantType, AbstractDict, Nothing}=nothing,
                              wait::Bool=true)
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
    _grpc_update(grpc_request(client.transport, Points_CreateFieldIndex_Client, req))
end

function _string_to_field_type(s::AbstractString)
    s == "keyword"  && return qdrant.var"FieldType".FieldTypeKeyword
    s == "integer"  && return qdrant.var"FieldType".FieldTypeInteger
    s == "float"    && return qdrant.var"FieldType".FieldTypeFloat
    s == "geo"      && return qdrant.var"FieldType".FieldTypeGeo
    s == "text"     && return qdrant.var"FieldType".FieldTypeText
    s == "bool"     && return qdrant.var"FieldType".FieldTypeBool
    s == "datetime" && return qdrant.var"FieldType".FieldTypeDatetime
    s == "uuid"     && return qdrant.var"FieldType".FieldTypeUuid
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

function delete_payload_index(client::QdrantClient{GRPCTransport}, collection::AbstractString,
                              field_name::AbstractString; wait::Bool=true)
    req = qdrant.DeleteFieldIndexCollection(
        collection, wait, field_name,
        nothing, UInt64(0),
    )
    _grpc_update(grpc_request(client.transport, Points_DeleteFieldIndex_Client, req))
end
