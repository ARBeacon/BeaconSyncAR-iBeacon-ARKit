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
    
    var session:ARSession? { arViewModel.sceneView?.session }
    
    var body: some View {
        ZStack{
            ARViewContainer(arViewModel: arViewModel).ignoresSafeArea(.all)
            Text(worldMappingStatusText).background(.white)
        }
        
    }
}

#Preview {
    ContentView()
}
