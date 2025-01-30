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
        Logger.addLog(label: "Initialize ARViewModel")
        sceneView = makeARView()
        loadModel()
        setupGestureRecognizer()
        Logger.addLog(label: "Finished Initialize ARViewModel")
    }
    
    public static var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            print("DEBUG: Found \(referenceImages.count) AR reference images")
            configuration.detectionImages = referenceImages
        }
        
        return configuration
    }
    
    func makeARView() -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.session.run(ARViewModel.defaultConfiguration, options: [.removeExistingAnchors,.resetSceneReconstruction,.resetTracking])
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

struct AnchorLog: Encodable{
    let name: String?
    let identifier: UUID
    let transform: simd_float4x4
}

// ARWorldMap Logging
extension ARViewModel {
    struct WorldMapLog: Encodable {
        let center: [Float]
        let extent: [Float]
    }
    
    func SIMD3FloatToArray(_ vector: SIMD3<Float>) -> [Float] {
        return [vector.x, vector.y, vector.z]
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            Task{
                let currentMap = try await session.currentWorldMap()
                let center = SIMD3FloatToArray(currentMap.center)
                let extent = SIMD3FloatToArray(currentMap.extent)
                Logger.addLog(
                    label: "Tracking Available",
                    content: WorldMapLog(
                        center: center,
                        extent: extent
                    )
                )
                
            }
        case .limited(let reason):
            Logger.addLog(
                label: "Tracking Limited",
                content: "Tracking is limited due to: \(reason)"
            )
        case .notAvailable:
            Logger.addLog(
                label: "Tracking Not Available"
            )
        }
    }
}

// Bunny Hit-Test and Rendering
extension ARViewModel {
    private func placeModel(at raycastResult: ARRaycastResult) {
        let bunnyAnchor = ARAnchor(name: "bunny", transform: raycastResult.worldTransform)
        sceneView?.session.add(anchor: bunnyAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            handleImageAnchor(imageAnchor, node: node)
        case _ where anchor.name == "bunny":
            handleBunnyAnchor(node: node, anchor: anchor)
        case _ as ARPlaneAnchor: break
        default: break
        }
        
        func handleImageAnchor(_ imageAnchor: ARImageAnchor, node: SCNNode) {
            
            Logger.addLog(
                label: "ARImageAnchor didAdd",
                content: AnchorLog(
                    name: imageAnchor.referenceImage.name,
                    identifier: imageAnchor.identifier,
                    transform: imageAnchor.transform
                )
            )
            
            let planeNode = createPlaneNode(for: imageAnchor)
            
            node.addChildNode(planeNode)
        }
        
        func handleBunnyAnchor(node: SCNNode, anchor: ARAnchor) {
            guard let modelNode = modelNode?.clone() else { return }
            
            Logger.addLog(
                label: "Bunny didAdd",
                content: AnchorLog(
                    name: anchor.name,
                    identifier: anchor.identifier,
                    transform: anchor.transform
                )
            )
            
            modelNode.position = SCNVector3Zero
            modelNode.eulerAngles = SCNVector3(-Double.pi / 2, -Double.pi / 2, 0)
            
            node.addChildNode(modelNode)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        for anchor in anchors {
            switch anchor {
            case let imageAnchor as ARImageAnchor:
                handleImageAnchor(imageAnchor)
            case _ where anchor.name == "bunny":
                handleBunnyAnchor(anchor: anchor)
            case _ as ARPlaneAnchor: break
            default: break
            }
        }
        
        func handleImageAnchor(_ imageAnchor: ARImageAnchor) {
            Logger.addLog(
                label: "ARImageAnchor didUpdate",
                content: AnchorLog(
                    name: imageAnchor.referenceImage.name,
                    identifier: imageAnchor.identifier,
                    transform: imageAnchor.transform)
            )
        }
        
        func handleBunnyAnchor(anchor: ARAnchor) {
            Logger.addLog(
                label: "Bunny didUpdate",
                content: AnchorLog(
                    name: anchor.name,
                    identifier: anchor.identifier,
                    transform: anchor.transform
                )
            )
        }
        
    }
}

// ImageAnchor
extension ARViewModel {
    private func createPlaneNode(for imageAnchor: ARImageAnchor) -> SCNNode {
        let referenceImage = imageAnchor.referenceImage
        let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        
        plane.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.8)
        
        return planeNode
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
        
        Logger.addLog(
            label: "Gesture Raycast",
            content: raycastResult.worldTransform
        )
        
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

