import PhotosUI
import SwiftUI

struct ScheduleImportView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var importResult: OCRImportResult?
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    @State private var isCameraPresented = false

    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("시간표 사진 선택", systemImage: "photo")
                    }

                    Button {
                        isCameraPresented = true
                    } label: {
                        Label("카메라로 촬영", systemImage: "camera")
                    }

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if isRecognizing {
                        ProgressView("시간표를 읽는 중")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let importResult {
                    Section("인식된 텍스트") {
                        Text(importResult.rawText.isEmpty ? "텍스트를 찾지 못했어요." : importResult.rawText)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }

                    Section("시간표 후보") {
                        if importResult.candidates.isEmpty {
                            Text("자동 후보가 없어요. 시간표 탭에서 직접 추가할 수 있습니다.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(importResult.candidates) { entry in
                                ScheduleEntryRow(entry: entry, periods: store.data.periods)
                            }

                            Button {
                                store.addEntries(importResult.candidates)
                            } label: {
                                Label("후보를 시간표에 추가", systemImage: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("가져오기")
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    await loadAndRecognize(newValue)
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraPicker { image in
                    Task {
                        await recognize(image)
                    }
                }
            }
        }
    }

    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isRecognizing = true
        errorMessage = nil
        importResult = nil

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw OCRError.invalidImage
            }

            await recognize(image)
        } catch {
            errorMessage = error.localizedDescription
            isRecognizing = false
        }
    }

    private func recognize(_ image: UIImage) async {
        isRecognizing = true
        errorMessage = nil
        importResult = nil
        selectedImage = image

        do {
            importResult = try await ocrService.recognizeSchedule(from: image, periods: store.data.periods)
        } catch {
            errorMessage = error.localizedDescription
        }

        isRecognizing = false
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImagePicked: (UIImage) -> Void
        var dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
