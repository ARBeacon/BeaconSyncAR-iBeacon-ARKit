//
//  ContentView.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/30/24.
//
import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var viewModel = ARViewModel()
    @State private var roomId: UUID?
    
    var worldMappingStatus: ARFrame.WorldMappingStatus {viewModel.worldMappingStatus}
    var worldMappingStatusText: String {
        switch worldMappingStatus {
        case .notAvailable: return "World mapping not available"
        case .limited: return "World mapping limited"
        case .mapped: return "World mapping complete"
        case .extending: return "World mapping extending"
        @unknown default: return "Unknown world mapping status"
        }
    }
    
    var body: some View {
        ZStack{
            ARSceneViewController(viewModel: viewModel, roomId: $roomId)
                .edgesIgnoringSafeArea(.all)
            Text(worldMappingStatusText)
        }
        
    }
}

#Preview {
    ContentView()
}
