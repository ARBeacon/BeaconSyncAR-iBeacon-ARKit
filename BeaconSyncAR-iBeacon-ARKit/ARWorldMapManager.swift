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
    var uuid: UUID? // UUID for managing ARWorldMap file on the backend, nil means never have previous version
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
                uuid = try await fetchAndApplyWorldMap(for: room)
            } catch {
                uuid = nil
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
    func saveCurrentWorldMapRoom() async throws {
        if let currentWorldMapRoom = currentARWorldMapRoom {
            let presignedURLResponse = try await getPresignedUploadLink(for: currentWorldMapRoom, room: currentWorldMapRoom.room)
            try await uploadCurrentWorldMap(to: presignedURLResponse.url)
            try await confirmUpload(currentUUID: currentWorldMapRoom.uuid, newUUID: presignedURLResponse.uuid, room: currentWorldMapRoom.room)
            DispatchQueue.main.async {
                self.currentARWorldMapRoom?.uuid = presignedURLResponse.uuid
            }
        }
    }
}

extension ARWorldMapManager{
    
    struct PresignedURLResponse: Codable {
        let url: URL
        let uuid: UUID
    }
    
    private func getPresignedUploadLink(for currentWorldMapRoom: ARWorldMapRoom, room: Room) async throws -> PresignedURLResponse {
        
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/ARWorldMap/getPresignedUploadUrl"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let presignedResponse = try JSONDecoder().decode(PresignedURLResponse.self, from: data)
        return presignedResponse
    }
    
    private func uploadCurrentWorldMap(to url: URL) async throws {
        guard let worldMapData = try await getCurrentARWorldMapData() else {
            throw NSError(domain: "ARWorldMapError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get world map data"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        print("Uploading worldMapData: \(worldMapData)")
        let (_, response) = try await URLSession.shared.upload(for: request, from: worldMapData)
        print("Done Uploading worldMapData")
        
        // Correctly cast URLResponse to HTTPURLResponse
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
        }
    }
    
    private func confirmUpload(currentUUID: UUID?, newUUID: UUID, room: Room) async throws {
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/ARWorldMap/presignedUploadConfirmation"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let parameters: [String: Any] = ["old_uuid": currentUUID?.uuidString ?? NSNull(), "uuid": newUUID.uuidString]
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("confirmUpload parameters: \(parameters)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Confirmation failed"])
        }
        print("Done Confirming Uploaded worldMapData")
    }
    
    private func fetchAndApplyWorldMap(for room: Room) async throws -> UUID {
        print("fetchAndApplyWorldMap")
        let presignedURLResponse = try await getPresignedDownloadLink(for: room)
        
        let (data, response) = try await URLSession.shared.data(from: presignedURLResponse.url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }
        
        applyARWorldMapData(data)
        return presignedURLResponse.uuid
    }
    
    private func getPresignedDownloadLink(for room: Room) async throws -> PresignedURLResponse {
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
        
        
        let presignedResponse = try JSONDecoder().decode(PresignedURLResponse.self, from: data)
        return presignedResponse
    }
}

extension ARWorldMapManager {
    
    private func getCurrentARWorldMapData() async throws -> Data? {
        func getCurrentWorldMap() async throws -> ARWorldMap? {
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
        guard let worldMap = try await getCurrentWorldMap() else {
            throw NSError(domain: "ARWorldMapError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No ARWorldMap in archive."])
        }
        return try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
    }
    
    private func applyARWorldMapData(_ data: Data) {
        do {
            let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            guard let unwrappedWorldMap = worldMap else {
                throw NSError(domain: "ARWorldMapError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ARWorldMap data."])
            }
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = unwrappedWorldMap
            arViewModel.sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            print("World map applied successfully.")
        } catch {
            print("Error decoding world map: \(error.localizedDescription)")
        }
    }
}
