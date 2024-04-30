//
//  ViewController.swift
//  ARProject
//
//  Created by Jin-Mac on 4/30/24.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var armarkers = [String: ARMarker]()
    
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resetTracking()
        loadData()
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func loadData() {
        guard let url = Bundle.main.url(forResource: "ARTest", withExtension: "json") else {
            fatalError("Unable to find JSON in bundle")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Unalble to load JSON")
        }
        
        let decoder = JSONDecoder()
        
        guard let loadedARMarkers = try? decoder.decode([String: ARMarker].self, from: data) else {
            fatalError("Unable to parse JSON.")
        }
        
        armarkers = loadedARMarkers
    }
    
    func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 3
        session.run(configuration)
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        
        guard let imageAnchor = anchor as? ARImageAnchor else { return node }
        let referenceImage = imageAnchor.referenceImage
        guard let name = referenceImage.name else { return node }
        guard let marker = armarkers[name] else { return nil }
        
        // Create a plane node representing the detected image
        let plane = SCNPlane(width: referenceImage.physicalSize.width,
                             height: referenceImage.physicalSize.height)
        plane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0.9)
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        node.addChildNode(planeNode)
        
        let spacing: Float = 0.005
        let titleNode = makeDescriptionTextNode(marker.name, font: UIFont.boldSystemFont(ofSize: 10))
        titleNode.pivotOnTopLeft()
        titleNode.position.x += Float(plane.width/2)+spacing
        titleNode.position.y += Float(plane.height/2)
        planeNode.addChildNode(titleNode)
        
        let (minBound, maxBound) = titleNode.boundingBox
        let textWidth = maxBound.x - minBound.x
        let textHeight = maxBound.y - minBound.y
        
        let descriptionNode = makeDescriptionTextNode(marker.description, font: UIFont.systemFont(ofSize: 4), maxWidth: 100)
        descriptionNode.pivotOnTopLeft()
        descriptionNode.position.x += Float(plane.width/2)+spacing
        descriptionNode.position.y = titleNode.position.y - titleNode.height - spacing
        planeNode.addChildNode(descriptionNode)
        
        let image = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.width / 8 * 5)
        image.firstMaterial?.diffuse.contents = UIImage(named: marker.image)
        
        let imageNode = SCNNode(geometry: image)
        imageNode.pivotOnTopLeft()
        imageNode.position.x += Float(plane.width/2)+spacing
        imageNode.position.y = descriptionNode.position.y - descriptionNode.height - spacing
        planeNode.addChildNode(imageNode)
        
        return node
    }
    
    func makeDescriptionTextNode(_ string: String, font: UIFont, maxWidth: Int? = nil) -> SCNNode {
        let textGeometry = SCNText(string: string, extrusionDepth: 0)
        textGeometry.flatness = 0.1
        textGeometry.font = font
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black
        
        if let maxWidth = maxWidth {
            textGeometry.containerFrame = CGRect(origin: .zero, size: CGSize(width: maxWidth, height: 500))
            textGeometry.isWrapped = true
        }
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(x: 0.002, y: 0.002, z: 0.002)
//        textNode.eulerAngles.x = -.pi / 2
        
        return textNode
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension ViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: sceneView)
        
        // 터치한 위치에서 가장 가까운 오브젝트를 식별합니다.
        let hitTestResults = sceneView.hitTest(touchLocation, options: nil)
        if let hitResult = hitTestResults.first,
           let node = hitResult.node as? SCNNode {
            // 오브젝트를 캡처하고 UIImage로 변환합니다.
            if let capturedImage = captureObject(node: node) {
                captureAugmentedImage(capturedImage)
            }
        }
    }
    
    func captureObject(node: SCNNode) -> UIImage? {
        let capturedImage = sceneView.snapshot()
            // 이미지를 원하는 크기로 자르기
        let croppedImageRect = CGRect(x: 100, y: 100, width: 200, height: 200)
        if let croppedImage = capturedImage.cgImage?.cropping(to: croppedImageRect) {
            let uiImage = UIImage(cgImage: croppedImage)
            // uiImage를 사용하세요!
            return uiImage
        }
        return nil
    }
    
    @objc func captureAugmentedImage(_ image: UIImage) {

        // Create a UIImageView with the captured image
        let modalImageView = UIImageView(image: image)
        modalImageView.contentMode = .scaleAspectFit
        modalImageView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        modalImageView.backgroundColor = .white

        // Add the UIImageView to a modal view controller and present it
        let modalViewController = UIViewController()
        modalViewController.view.addSubview(modalImageView)
        modalViewController.modalPresentationStyle = .automatic
        present(modalViewController, animated: true, completion: nil)
    }
}

