//
//  ARSceneViewController.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/31/24.
//
import SwiftUI
import ARKit
import SceneKit

class ARViewModel: ObservableObject {
    @Published var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    var currentRoomID: UUID?
}

struct ARSceneViewController: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ARViewModel
    @Binding var roomId: UUID?
    
    func makeUIViewController(context: Context) -> ARSCNViewController {
        let viewController = ARSCNViewController(viewModel: viewModel)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ARSCNViewController, context: Context) {
        if roomId != viewModel.currentRoomID {
            Task {
                if viewModel.currentRoomID != nil {
                    // let data = try await uiViewController.saveCurrentWorldMap()
                    // TODO: Call API to upload worldMap to currentRoomID
                }
                // TODO: Call API to download worldMap using roomId
                // try uiViewController.loadWorldMap(from: <#T##Data#>)
            }
        }
        viewModel.currentRoomID = roomId
    }
}

class ARSCNViewController: UIViewController {
    var sceneView: ARSCNView!
    var modelNode: SCNNode!
    private var viewModel: ARViewModel
    
    init(viewModel: ARViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate = self
        view.addSubview(sceneView)
        
        loadModel()
        
        sceneView.session.run(defaultConfiguration)
        
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    private func loadModel() {
        guard let modelScene = SCNScene(named: "stanford-bunny.usdz"),
              let node = modelScene.rootNode.childNodes.first else {
            print("Failed to load the USDZ model.")
            return
        }
        modelNode = node
    }
    
    @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: sceneView)
        
        guard let raycastQuery = sceneView.raycastQuery(from: touchLocation, allowing: .estimatedPlane, alignment: .horizontal) else {
            return
        }
        
        guard let raycastResult = sceneView.session.raycast(raycastQuery).first else {
            return
        }
        
        placeModel(at: raycastResult)
    }
    
    private func placeModel(at raycastResult: ARRaycastResult) {
        let bunnyAnchor = ARAnchor(name: "bunny", transform: raycastResult.worldTransform)
        sceneView.session.add(anchor: bunnyAnchor)
    }
    
    private func plotFeaturePoints(frame: ARFrame) {
        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }
        let points = rawFeaturePoints.points
        
        let sphereGeometry = SCNSphere(radius: 0.001)
        sphereGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        for point in points {
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.name = "FeaturePoint"
            sphereNode.position = SCNVector3(point.x, point.y, point.z)
            sceneView.scene.rootNode.addChildNode(sphereNode)
        }
    }
}

extension ARSCNViewController: ARSessionDelegate{
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        viewModel.worldMappingStatus = frame.worldMappingStatus
        sceneView.scene.rootNode.childNodes.filter { $0.name == "FeaturePoint" }.forEach { $0.removeFromParentNode() }
        plotFeaturePoints(frame: frame)
    }
}

extension ARSCNViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor.name == "bunny",
              let modelNode = modelNode?.clone() else {
            return
        }
        
        modelNode.position = SCNVector3Zero
        modelNode.eulerAngles = SCNVector3(-Double.pi / 2, -Double.pi / 2, 0)
        
        node.addChildNode(modelNode)
    }
}

extension ARSCNViewController {
    
    func saveCurrentWorldMap() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            sceneView.session.getCurrentWorldMap { worldMap, error in
                if let error = error {
                    print("Error saving current world map: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let worldMap = worldMap else {
                    let unknownError = NSError(domain: "ARKitErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    continuation.resume(throwing: unknownError)
                    return
                }
                
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                    continuation.resume(returning: data)
                } catch {
                    print("Error archiving world map: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }
    
    func loadWorldMap(from data: Data) throws {
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else { fatalError("Cannot unarchive ARWorldMap.") }
        let configuration = self.defaultConfiguration
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
