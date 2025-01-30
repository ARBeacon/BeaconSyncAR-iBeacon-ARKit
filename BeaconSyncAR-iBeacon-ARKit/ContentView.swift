//
//  ContentView.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/30/24.
//
import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var arViewModel: ARViewModel = ARViewModel()
    @StateObject private var roomManager: RoomManager = RoomManager()
    @StateObject private var arWorldMapManager: ARWorldMapManager
    
    @ObservedObject var logger: Logger = Logger.get()
    
    init(logger: Logger? = nil) {
        let arViewModel = ARViewModel()
        let roomManager = RoomManager()
        _arWorldMapManager = StateObject(wrappedValue: ARWorldMapManager(roomManager: roomManager, arViewModel: arViewModel))
        
        _arViewModel = StateObject(wrappedValue: arViewModel)
        _roomManager = StateObject(wrappedValue: roomManager)
        
        if let logger {
            logger.addLog(label: "ContentView Initialize", content: "Mocked Logger")
            _logger = ObservedObject(wrappedValue: logger)
        }
        else {
            let logger = Logger.get()
            logger.addLog(label: "ContentView Initialize")
            _logger = ObservedObject(wrappedValue:logger)
        }
    }
    
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
        NavigationStack {
            ZStack{
                ARViewContainer(arViewModel: arViewModel).ignoresSafeArea(.all)
                VStack{
                    VStack{
                        Text(worldMappingStatusText)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        if let roomName {
                            VStack{
                                Text("Welcome To").font(.caption2)
                                Text("\(roomName)").bold()
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    Spacer()
                }
                
                VStack{
                    Spacer()
                    HStack{
                        Button(action: {
                            Task{
                                try await arWorldMapManager.saveCurrentWorldMapRoom()
                            }
                        }) {
                            Text("Save & Upload")
                                .padding()
                                .background(disableSaveButton ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .opacity(disableSaveButton ? 0.6 : 1.0)
                        }
                        .disabled(disableSaveButton)
                        .animation(.easeInOut, value: disableSaveButton)
                        .padding()
                        
                        NavigationLink(destination: LogView(logger: logger)) {
                            Text("Open Log").padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .opacity(1)
                        }.navigationBarTitleDisplayMode(.automatic)
                    }
                    
                }
                
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let logger = Logger.sampleLogger()
        return ContentView(logger: logger)
    }
}
