//
//  ContentView.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/30/24.
//
import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var roomManager = RoomManager()
    
    var worldMappingStatus: ARFrame.WorldMappingStatus {arViewModel.worldMappingStatus}
    var worldMappingStatusText: String {
        switch worldMappingStatus {
        case .notAvailable: return "World mapping not available"
        case .limited: return "World mapping limited"
        case .mapped: return "World mapping complete"
        case .extending: return "World mapping extending"
        @unknown default: return "Unknown world mapping status"
        }
    }
    
    var roomName:String? { roomManager.currentRoom?.name }
    
    var session:ARSession? { arViewModel.sceneView?.session }
    
    var disableSaveButton: Bool {
        switch worldMappingStatus {
        case .mapped: return false
        case .extending: return false
        default: return true
        }
    }
    
    var body: some View {
        ZStack{
            ARViewContainer(arViewModel: arViewModel).ignoresSafeArea(.all)
            VStack{
                VStack{
                    Text(worldMappingStatusText).background(.white)
                    if let roomName {
                        Text("Current Room: \(roomName)").background(.white)
                    }
                }
                .padding()
                Spacer()
            }
            
            VStack{
                Spacer()
                Button(action: {
                    print("Save")
                }) {
                    Text("Save")
                        .padding()
                        .background(disableSaveButton ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .opacity(disableSaveButton ? 0.6 : 1.0)
                }
                .disabled(disableSaveButton)
                .animation(.easeInOut, value: disableSaveButton)
                .padding()
            }
            
        }
        
    }
}

#Preview {
    ContentView()
}
