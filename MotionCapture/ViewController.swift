//
//  ViewController.swift
//  MotionCapture
//
//  Created by S310 on 2020/11/08.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate, UIGestureRecognizerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    let nameList = ["spine_6_joint"]
    var nodePosition: [String: SCNVector3] = [:]
    
    var image = UIImage(named: "art.scnassets/no_image.png")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        
        // ビューのデリゲートを設定する
        sceneView.session.delegate = self
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }
        
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
            fatalError("People occlusion is not supported on this device.")
        }

        // セッション構成を作成する
        let configuration = ARBodyTrackingConfiguration()
        configuration.planeDetection = .horizontal
        //configuration.frameSemantics = .personSegmentationWithDepth

        // ビューのセッションを実行します
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // ビューのセッションを一時停止します
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else {
                return
            }
            setARBodyAnchor(anchor: bodyAnchor)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else {
                return
            }
            setARBodyAnchor(anchor: bodyAnchor)
        }
    }
    
    func checkJointName(name: String)-> Bool {
        for checkName in nameList {
            if name == checkName {
                return true
            }
        }
        return false
    }
    
    func setARBodyAnchor(anchor: ARBodyAnchor) {
        // skeleton 取得
        let skeleton = anchor.skeleton
        // skeleton の パーツ名でloop
        for jointName in skeleton.definition.jointNames {
            let jointType = ARSkeleton.JointName(rawValue: jointName)
            if let transform = skeleton.modelTransform(for: jointType) {
                /// jointTypeの位置・回転をキャスト
                let partsPoint = SCNMatrix4(transform)
                /// 基準点 hipの位置・回転をキャスト
                let hipPoint = SCNMatrix4(anchor.transform)
                /// func SCNMatrix4Mult(_ a: SCNMatrix4, _ b: SCNMatrix4) -> SCNMatrix4で行列を合成するときは、左のaが後にやる方、右のbが先にやる方、という風に考えて合成します。
                let matrix = SCNMatrix4Mult(partsPoint, hipPoint)
                /// ノードの座標を設定
                // + 1して実際の位置の右側に表示する様にする
                let position = SCNVector3(matrix.m41, matrix.m42 - 0.1, matrix.m43)
                nodePosition[jointName] = position
                if checkJointName(name: jointName) {
                    if let nodeToUpdate = sceneView.scene.rootNode.childNode(withName: jointName, recursively: false) {
                        /// 既に追加されているので、位置の更新のみ行う
                        nodeToUpdate.isHidden = false
                        nodeToUpdate.position = position
                        nodeToUpdate.geometry?.firstMaterial?.diffuse.contents = image
                    } else {
                        let photoNode = createPhotoNode(image, position: position, jointName: jointName)
                        sceneView.scene.rootNode.addChildNode(photoNode)
                    }
                }
            } else {
                if let nodeToHide = sceneView.scene.rootNode.childNode(withName: jointName, recursively: false) {
                    nodeToHide.isHidden = true
                }
            }
        }
    }
    
    @IBAction func photoButtonTapped(_ sender: Any) {
        showUIImagePicker()
    }
    
    private func showUIImagePicker() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let pickerView = UIImagePickerController()
            pickerView.sourceType = .photoLibrary
            pickerView.delegate = self
            pickerView.modalPresentationStyle = .overFullScreen
            self.present(pickerView, animated: true, completion: nil)
        }
    }
    
    private func createPhotoNode(_ image: UIImage, position: SCNVector3, jointName: String) -> SCNNode {
        let node = SCNNode()
        //let scale: CGFloat = 0.5
        let geometry = SCNBox(width: 0.6,
                              height: 0.8,
                                length: 0.00000001,
                                chamferRadius: 0.0)
        geometry.firstMaterial?.diffuse.contents = image
        node.geometry = geometry
        node.position = position
        node.name = jointName
        return node
    }
    
    var lastGestureScale: Float = 1
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        print("pinch!")
        if let photoNode = sceneView.scene.rootNode.childNode(withName: nameList[0], recursively: true) {
            /*if recognizer.state == .began {
                let lastGestureScale = 1
            }*/

            let newGestureScale: Float = Float(recognizer.scale)

            // ここで直前のscaleとのdiffぶんだけ取得しときます
            let diff = newGestureScale - lastGestureScale

            let currentScale = photoNode.scale

            // diff分だけscaleを変化させる。1は1倍、1.2は1.2倍の大きさになります。
            photoNode.scale = SCNVector3Make(
                currentScale.x * (1 + diff),
                currentScale.y * (1 + diff),
                currentScale.z * (1 + diff)
            )
            // 保存しとく
            lastGestureScale = newGestureScale
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        image = info[.originalImage] as! UIImage
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
