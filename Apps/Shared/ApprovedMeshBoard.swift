import SwiftUI
import SceneKit
import UIKit

/// Restricted GLB reader for the verified master asset (indexed float32 triangles).
/// The asset uses XY for the tabletop and Z for height.
private struct ApprovedGLB {
    let json: [String: Any]
    let binary: Data
    init?() {
        guard let url = Bundle.main.url(forResource: "master-piece", withExtension: "glb"),
              let data = try? Data(contentsOf: url), data.count >= 28 else { return nil }
        func word(_ offset: Int) -> Int {
            Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian)
        }
        guard word(0) == 0x46546c67, word(4) == 2 else { return nil }
        let end = 20 + word(12)
        guard end + 8 <= data.count,
              let object = try? JSONSerialization.jsonObject(with: data.subdata(in: 20..<end)),
              let dict = object as? [String: Any],
              end + 8 + word(end) <= data.count else { return nil }
        json = dict
        binary = data.subdata(in: (end+8)..<(end+8+word(end)))
    }
    func accessor(_ index: Int, width: Int, component: Int) -> (Data, Int)? {
        guard let accessors = json["accessors"] as? [[String: Any]],
              let views = json["bufferViews"] as? [[String: Any]],
              accessors.indices.contains(index) else { return nil }
        let a = accessors[index]
        guard let v = a["bufferView"] as? Int, views.indices.contains(v),
              let count = a["count"] as? Int, count > 0,
              a["componentType"] as? Int == component else { return nil }
        let view = views[v]
        guard (view["byteStride"] as? Int ?? width) == width else { return nil }
        let start = (view["byteOffset"] as? Int ?? 0) + (a["byteOffset"] as? Int ?? 0)
        guard start >= 0, start + count * width <= binary.count else { return nil }
        return (binary.subdata(in: start..<(start + count * width)), count)
    }
    func piece(color: UIColor) -> SCNNode? {
        guard let meshes = json["meshes"] as? [[String: Any]],
              let nodes = json["nodes"] as? [[String: Any]] else { return nil }
        let root = SCNNode()
        for node in nodes {
            guard let index = node["mesh"] as? Int else { continue }
            guard meshes.indices.contains(index),
                  let primitives = meshes[index]["primitives"] as? [[String: Any]],
                  let p = primitives.first,
                  let attrs = p["attributes"] as? [String: Int],
                  let pos = attrs["POSITION"], let idx = p["indices"] as? Int,
                  let (vertices, count) = accessor(pos, width: 12, component: 5126),
                  let (indices, indexCount) = accessor(idx, width: 4, component: 5125),
                  indexCount % 3 == 0 else { return nil }
            let source = SCNGeometrySource(data: vertices, semantic: .vertex, vectorCount: count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
            var sources = [source]
            if let normal = attrs["NORMAL"], let (data, n) = accessor(normal, width: 12, component: 5126), n == count {
                sources.append(SCNGeometrySource(data: data, semantic: .normal, vectorCount: n, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12))
            }
            if let uv = attrs["TEXCOORD_0"], let (data, n) = accessor(uv, width: 8, component: 5126), n == count {
                sources.append(SCNGeometrySource(data: data, semantic: .texcoord, vectorCount: n, usesFloatComponents: true, componentsPerVector: 2, bytesPerComponent: 4, dataOffset: 0, dataStride: 8))
            }
            let element = SCNGeometryElement(data: indices, primitiveType: .triangles, primitiveCount: indexCount / 3, bytesPerIndex: 4)
            let geometry = SCNGeometry(sources: sources, elements: [element])
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.roughness.contents = 0.55
            material.metalness.contents = 0
            let name = node["name"] as? String ?? ""
            if name == "maple body" {
                material.diffuse.contents = UIImage(named: "maple.jpg") ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "maple", ofType: "jpg") ?? "")
                if material.diffuse.contents == nil { material.diffuse.contents = UIColor(red: 0.91, green: 0.76, blue: 0.53, alpha: 1) }
            } else {
                let number = Int(name.split(separator: " ").last ?? "") ?? 0
                material.diffuse.contents = UIColor(red: 0.12, green: 0.075, blue: 0.035, alpha: 1)
            }
            geometry.materials = [material]
            let child = SCNNode(geometry: geometry)
            root.addChildNode(child)
        }
        return root.childNodes.count == 28 ? root : nil
    }
}

struct ApprovedMeshBoard: View {
    let playerCount: Int
    let seatColors: [Int]
    var marbles: [MeshMarble] = []
    private static let asset = ApprovedGLB()
    static let available: Bool = asset?.piece(color: .red) != nil
    private let palette: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange]
    var body: some View {
        GeometryReader { geo in
            if let scene = makeScene(size: geo.size) {
                TransparentBoardScene(scene: scene)
                    .allowsHitTesting(false)
            }
        }
    }
    private func makeScene(size: CGSize) -> SCNScene? {
        guard let asset = Self.asset, (3...6).contains(playerCount), size.width > 0, size.height > 0 else { return nil }
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let n = Double(playerCount)
        let extent = 970 / (2 * sin(.pi / n)) + 160
        for seat in 0..<playerCount {
            let colorIndex = seatColors.indices.contains(seat) ? seatColors[seat] : seat
            guard let piece = asset.piece(color: palette[colorIndex % palette.count]) else { return nil }
            // Master mesh x=(SVG x-634)/1000, y=(176-SVG y)/1000.
            piece.position = SCNVector3(0, Float((485 / tan(.pi / n) - 48) / 1000), 0)
            let pivot = SCNNode()
            pivot.eulerAngles.z = Float(-Double.pi - Double(seat) * 2 * Double.pi / n)
            pivot.addChildNode(piece)
            scene.rootNode.addChildNode(pivot)
        }
        for marble in marbles {
            let sphere = SCNSphere(radius: 0.025)
            sphere.segmentCount = 48
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = palette[marble.color % palette.count]
            material.roughness.contents = 0.09
            material.metalness.contents = 0
            material.clearCoat.contents = 1.0
            material.clearCoatRoughness.contents = 0.06
            sphere.materials = [material]
            let node = SCNNode(geometry: sphere)
            let scale = min(size.width, size.height) / CGFloat(2 * extent)
            node.position = SCNVector3(Float((marble.point.x - size.width / 2) / scale / 1000), Float((size.height / 2 - marble.point.y) / scale / 1000), 0.035)
            scene.rootNode.addChildNode(node)
        }
        let camera = SCNNode()
        camera.name = "camera"
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = extent / 1000 * max(1, Double(size.height / size.width))
        camera.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1000
        key.eulerAngles = SCNVector3(-0.4, -0.5, 0)
        scene.rootNode.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 220
        fill.eulerAngles = SCNVector3(0.6, 0.8, 0)
        scene.rootNode.addChildNode(fill)
        return scene
    }
}

struct MeshMarble {
    let point: CGPoint
    let color: Int
}

private struct TransparentBoardScene: UIViewRepresentable {
    let scene: SCNScene
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.layer.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
    }
}
