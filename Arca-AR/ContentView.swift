import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        
        // 1. Настройка распознавания изображений
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            configuration.detectionImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 1
        }
        
        configuration.planeDetection = [.horizontal]
        
        // 2. Включаем LiDAR-окклюзию именно здесь!
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            print("✅ LiDAR и окклюзия успешно включены!")
        } else {
            print("⚠️ Устройство не поддерживает sceneReconstruction (.mesh)")
        }
        
        arView.session.delegate = context.coordinator
        arView.session.run(configuration)
        
        context.coordinator.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - ARSession Delegate Coordinator
    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var isPlaced = false
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let imageAnchor = anchor as? ARImageAnchor {
                    print("🎯 Карточка распознана:", imageAnchor.name ?? "без имени")
                    
                    if !isPlaced {
                        isPlaced = true
                        placeArch(at: imageAnchor)
                    } else {
                        print("Is not placed!!!")
                    }
                }
            }
        }
        
        // ВНИМАНИЕ: Отсюда дублирующийся makeUIView удален!
        
        private func placeArch(at imageAnchor: ARImageAnchor) {
            guard let arView = arView else { return }
            
            // 1. Берем координаты карточки в мировом пространстве (чтобы арка не наклонялась вслед за карточкой)
            let transform = imageAnchor.transform
            let worldPosition = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            
            let worldAnchor = AnchorEntity(world: worldPosition)
            
            do {
                // 2. Загружаем и позиционируем арку
                let archModel = try ModelEntity.load(named: "arca")
                archModel.position = SIMD3<Float>(0.0, -0.8, -2.0)
                worldAnchor.addChild(archModel)
                
                // 3. Создаем ручной маскирующий экран (Occluder) для монитора/карточки
                // Задаем ширину (0.5м) и высоту (0.4м) под размеры монитора или зоны перед аркой
                let planeMesh = MeshResource.generatePlane(width: 0.5, depth: 0.4)
                let occluder = ModelEntity(mesh: planeMesh, materials: [OcclusionMaterial()])
                
                // Поворачиваем плоскость на 90 градусов по X, чтобы она стояла вертикально, как монитор
                occluder.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                // Ставим маску ровно в точку карточки
                occluder.position = SIMD3<Float>(0.0, 0.0, 0.0)
                
                worldAnchor.addChild(occluder)
                
                // Создаем источник света
                let lightEntity = Entity()
                var directionalLight = DirectionalLightComponent()
                directionalLight.color = .white
                directionalLight.intensity = 3000 // Яркость света (настройте под себя, например 2000-5000)
                lightEntity.components[DirectionalLightComponent.self] = directionalLight

                // Поворачиваем свет немного сверху и спереди
                lightEntity.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])

                worldAnchor.addChild(lightEntity)
                
                arView.scene.addAnchor(worldAnchor)
                print("Арка и маска успешно размещены!")
            } catch {
                print("Ошибка загрузки: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
