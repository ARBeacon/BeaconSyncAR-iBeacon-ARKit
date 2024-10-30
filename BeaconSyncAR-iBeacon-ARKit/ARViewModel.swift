//
//  ARViewModel.swift
//  BeaconSyncAR-iBeacon-ARKit
//
//  Created by Maitree Hirunteeyakul on 10/31/24.
//
import SwiftUI
import SceneKit
import ARKit

class ARViewModel: NSObject, ObservableObject {
    @Published var sceneView: ARSCNView?
    @Published var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    var modelNode: SCNNode!
    
    override init() {
        super.init()
        sceneView = makeARView()
        loadModel()
        setupGestureRecognizer()
    }
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }
    
    func makeARView() -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.session.run(defaultConfiguration, options: [.removeExistingAnchors,.resetSceneReconstruction,.resetTracking])
        return sceneView
    }
    
}

// FeaturePoints
extension ARViewModel: ARSessionDelegate, ARSCNViewDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.worldMappingStatus = frame.worldMappingStatus
        self.plotFeaturePoints(frame: frame)
    }
    
    private func plotFeaturePoints(frame: ARFrame) {
        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }
        
        let points = rawFeaturePoints.points
        
        sceneView?.scene.rootNode.childNodes.filter { $0.name == "FeaturePoint" }.forEach { $0.removeFromParentNode() }
        
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.001))
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        
        points.forEach { point in
            let clonedSphereNode = sphereNode.clone()
            clonedSphereNode.name = "FeaturePoint"
            clonedSphereNode.position = SCNVector3(point.x, point.y, point.z)
            sceneView?.scene.rootNode.addChildNode(clonedSphereNode)
        }
    }
}

// Bunny Hit-Test
extension ARViewModel {
    private func placeModel(at raycastResult: ARRaycastResult) {
        let bunnyAnchor = ARAnchor(name: "bunny", transform: raycastResult.worldTransform)
        sceneView?.session.add(anchor: bunnyAnchor)
    }
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

// Guesture Set-up Hit-Test
extension ARViewModel {
    func setupGestureRecognizer() {
        guard let sceneView = sceneView else { return }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: sceneView)
        
        guard let raycastQuery = sceneView?.raycastQuery(from: touchLocation, allowing: .estimatedPlane, alignment: .horizontal) else {
            return
        }
        
        guard let raycastResult = sceneView?.session.raycast(raycastQuery).first else {
            return
        }
        
        placeModel(at: raycastResult)
    }
}

// 3D Model Loading
extension ARViewModel {
    private func loadModel() {
        guard let modelScene = SCNScene(named: "stanford-bunny.usdz"),
              let node = modelScene.rootNode.childNodes.first else {
            print("Failed to load the USDZ model.")
            return
        }
        modelNode = node
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arViewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        return arViewModel.sceneView ?? ARSCNView()
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

