# ============================================================================
# Snapshots API — gRPC transport
# ============================================================================

function create_snapshot(conn::QdrantConnection{GRPCTransport}, collection::AbstractString)
    t = conn.transport
    req = qdrant.CreateSnapshotRequest(collection)
    resp = grpc_request(t, Snapshots_Create_Client, req)
    sd = resp.snapshot_description
    info = sd === nothing ? SnapshotInfo("", nothing, 0, nothing) :
        SnapshotInfo(sd.name, nothing, Int(sd.size), isempty(sd.checksum) ? nothing : sd.checksum)
    QdrantResponse(info, "ok", 0.0)
end

function list_snapshots(conn::QdrantConnection{GRPCTransport}, collection::AbstractString)
    t = conn.transport
    req = qdrant.ListSnapshotsRequest(collection)
    resp = grpc_request(t, Snapshots_List_Client, req)
    result = SnapshotInfo[SnapshotInfo(sd.name, nothing, Int(sd.size),
                                       isempty(sd.checksum) ? nothing : sd.checksum)
                          for sd in resp.snapshot_descriptions]
    QdrantResponse(result, "ok", 0.0)
end

function delete_snapshot(conn::QdrantConnection{GRPCTransport}, collection::AbstractString,
                         name::AbstractString)
    t = conn.transport
    req = qdrant.DeleteSnapshotRequest(collection, name)
    grpc_request(t, Snapshots_Delete_Client, req)
    QdrantResponse(true, "ok", 0.0)
end
