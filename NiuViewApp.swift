import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var imageData: Data = Data()
    @State private var selectedPhotos: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var showBottomBar = false
    @State private var selectedTab = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(selectedPhotos.indices, id: \.self) { index in
                let photo = selectedPhotos[index]
                Image(uiImage: photo).resizable().scaledToFill().ignoresSafeArea()
                    .tag(Int(index))
                    .onTapGesture {
                        withAnimation(.easeInOut) { showBottomBar.toggle() }
                    }
            }
        }
        .ignoresSafeArea()
        .tabViewStyle(.page(indexDisplayMode: .never))
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedPhotos: $selectedPhotos)
        }
        .overlay {
            VStack {
                Spacer()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(selectedPhotos.indices, id: \.self) { index in
                            let photo = selectedPhotos[index]
                            Image(uiImage: photo).resizable().scaledToFit().padding()
                                .onTapGesture {
                                    selectedTab = Int(index)
                                }
                                .onLongPressGesture {
                                    selectedPhotos.remove(at: index)
                                }
                        }
                        // 添加
                        Button { showPhotoPicker.toggle() } label: { Image(systemName: "plus.square.dashed").resizable().scaledToFit() }.padding()
                        
                        // 清空
                        if !selectedPhotos.isEmpty {
                            Button { selectedPhotos = [] } label: { Image(systemName: "trash.square").resizable().scaledToFit() }.padding()
                        }
                        
                        // 读取
                        if imageData.count > 2 {
                            Button {
                                if let base64EncodedImages = try? JSONDecoder().decode([Data].self, from: imageData) {
                                    selectedPhotos = base64EncodedImages.compactMap { UIImage(data: $0) ?? nil }
                                    alertMessage = "读取了: \(imageData)"
                                    showAlert.toggle()
                                }
                            } label: { Image(systemName: "square.and.arrow.up").resizable().scaledToFit().padding() }
                        }
                        
                        // 保存
                        Button {
                            let base64EncodedImages = selectedPhotos.compactMap { $0.pngData() }
                            imageData = try! JSONEncoder().encode(base64EncodedImages)
                            UserDefaults.standard.set(imageData, forKey: "images")
                            if UserDefaults.standard.synchronize() {
                                alertMessage = "保存了: \(imageData)"
                            } else { alertMessage = "保存失败" }
                            showAlert.toggle()
                        } label: { Image(systemName: "square.and.arrow.down").resizable().scaledToFit().padding() }
                        

                    }
                }
                .frame(height: UIScreen.main.bounds.size.height * 0.1)
                .background(.regularMaterial)
            }.opacity(showBottomBar ? 1.0: 0)
        }
        .onAppear {
            if UserDefaults.standard.data(forKey: "images") == nil {
                UserDefaults.standard.set(Data(), forKey: "images")
            } else {
                imageData = UserDefaults.standard.data(forKey: "images")!
                print("\(imageData)")
            }
            if selectedPhotos.isEmpty { showBottomBar = true }
        }
        .alert(alertMessage, isPresented: $showAlert) { Button("OK") {} }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedPhotos: [UIImage]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 允许选择多张图片
        config.filter = .images // 只显示图片
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            // 创建一个临时数组以存储加载的图片
            var loadedImages = [(index: Int, image: UIImage)]()
            for (index, result) in results.enumerated() {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    let itemProvider = result.itemProvider
                    itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                // 将图片和它的选择索引存储在临时数组中
                                loadedImages.append((index: index, image: uiImage))

                                // 当所有图片加载完成时，根据索引排序并更新绑定的数组
                                if loadedImages.count == results.count {
                                    self.parent.selectedPhotos += loadedImages
                                        .sorted(by: { $0.index < $1.index }) // 按索引排序
                                        .map { $0.image } // 提取排序后的图片
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@main
struct NiuViewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
