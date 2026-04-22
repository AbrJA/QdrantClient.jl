# ============================================================================
# gRPC Snapshots API — dispatch on GRPCTransport
# ============================================================================

function create_snapshot(c::QdrantConnection, collection::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.CreateSnapshotRequest(collection)
    resp = grpc_request(transport, Snapshots_Create_Client, req)
    sd = resp.snapshot_description
    sd === nothing && return SnapshotInfo("", nothing, 0, nothing)
    SnapshotInfo(sd.name, nothing, Int(sd.size), isempty(sd.checksum) ? nothing : sd.checksum)
end

function list_snapshots(c::QdrantConnection, collection::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.ListSnapshotsRequest(collection)
    resp = grpc_request(transport, Snapshots_List_Client, req)
    SnapshotInfo[SnapshotInfo(sd.name, nothing, Int(sd.size),
                              isempty(sd.checksum) ? nothing : sd.checksum)
                 for sd in resp.snapshot_descriptions]
end

function delete_snapshot(c::QdrantConnection, collection::AbstractString,
                         name::AbstractString, ::Val{:grpc})
    transport = c.transport::GRPCTransport
    req = qdrant.DeleteSnapshotRequest(collection, name)
    grpc_request(transport, Snapshots_Delete_Client, req)
    true
end
