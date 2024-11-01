//
//  ARWorldMapManager.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/31/24.
//
import Foundation
import Combine
import ARKit

struct ARWorldMapRoom: Codable, Hashable {
    var uuid: UUID?
    let room: Room
}

class ARWorldMapManager: ObservableObject {
    @Published private(set) var currentARWorldMapRoom: ARWorldMapRoom? // to store the last room so we can save before load a new one
    
    private var roomManager: RoomManager
    private var arViewModel: ARViewModel
    private var subscriptions = Set<AnyCancellable>()
    
    init(roomManager: RoomManager, arViewModel: ARViewModel) {
        self.roomManager = roomManager
        self.arViewModel = arViewModel
        setupBindings()
    }
    
    private func setupBindings() {
        roomManager.$currentRoom
            .compactMap { $0 }
            .sink { [weak self] room in
                Task {
                    await self?.handleRoomUpdates(in: room)
                }
            }
            .store(in: &subscriptions)
    }
    
    private func handleRoomUpdates(in room: Room) async {
        do {
            try await saveCurrentWorldMapRoom()
            // Fetch and apply new ARWorldMapData for the new room
            
            let uuid: UUID?
            do {
                uuid = try await pullAndResloveCurrentWorldMapRoom(for: room)
            } catch {
                uuid = nil // This room have no Map associated to
            }
            
            // Update the current AR world map room
            DispatchQueue.main.async {
                self.currentARWorldMapRoom = ARWorldMapRoom(uuid: uuid, room: room)
            }
        } catch {
            print("Error handling room updates: \(error.localizedDescription)")
        }
    }
}

extension ARWorldMapManager{
    public func saveCurrentWorldMapRoom() async throws {
        if let currentWorldMapRoom = currentARWorldMapRoom {
            let newUUID = try await uploadCurrentWorldMap(prev_uuid: currentWorldMapRoom.uuid, for: currentWorldMapRoom.room)
            DispatchQueue.main.async {
                self.currentARWorldMapRoom?.uuid = newUUID
            }
        }
    }
    
    private func pullAndResloveCurrentWorldMapRoom(for room: Room) async throws -> UUID {
        let downloadARWorldMapResponse = try await downloadARWorldMap(for: room)
        applyARWorldMapData(downloadARWorldMapResponse.arWorldMap)
        return downloadARWorldMapResponse.uuid
    }
}

// API-facing module
extension ARWorldMapManager{
    
    struct UploadARWorldMapParams: Codable{
        let dataBase64Encoded: String
        let prev_uuid: UUID?
    }
    
    struct UploadARWorldMapResponse: Codable{
        let id: UUID
    }
    
    private func uploadCurrentWorldMap(prev_uuid: UUID?, for room: Room) async throws -> UUID {
        guard let worldMap = try await getCurrentWorldMap() else {
            throw NSError(domain: "ARWorldMapError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No ARWorldMap in archive."])
        }
        let worldMapData = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        let dataBase64Encoded = worldMapData.base64EncodedString()
        
        let body = UploadARWorldMapParams(dataBase64Encoded: dataBase64Encoded, prev_uuid: prev_uuid)
        
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/ARWorldMap/upload"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.httpBody = try? JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("Uploading worldMapData: \(worldMapData)")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("Done Uploading worldMapData")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
        }
        
        let uploadRespond = try JSONDecoder().decode(UploadARWorldMapResponse.self, from: data)
        return uploadRespond.id
    }
    
    struct DownloadARWorldMapResponse{
        let arWorldMap: ARWorldMap
        let uuid: UUID
    }
    
    private func downloadARWorldMap(for room: Room) async throws -> DownloadARWorldMapResponse {
        
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/ARWorldMap"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        struct DownloadRespond: Codable {
            let dataBase64Encoded: String
            let uuid: UUID
        }
        let downloadRespond = try JSONDecoder().decode(DownloadRespond.self, from: data)
        guard let ARWorldMapData = Data(base64Encoded: downloadRespond.dataBase64Encoded) else{
            throw NSError(domain: "DataDecodeError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode world map data"])
        }
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: ARWorldMapData) else{
            throw NSError(domain: "ARWorldMapError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get world map data"])
        }
        let downloadARWorldMapResponse = DownloadARWorldMapResponse(arWorldMap: worldMap, uuid: downloadRespond.uuid)
        return downloadARWorldMapResponse
    }
}

// ARSession-facing module
extension ARWorldMapManager {
    
    private func getCurrentWorldMap() async throws -> ARWorldMap? {
        guard let arSession = await arViewModel.sceneView?.session else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            arSession.getCurrentWorldMap { worldMap, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let worldMap = worldMap {
                    continuation.resume(returning: worldMap)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ARSessionError",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error obtaining world map"]
                    ))
                }
            }
        }
    }
    
    private func applyARWorldMapData(_ worldMap: ARWorldMap) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.initialWorldMap = worldMap
        arViewModel.sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
