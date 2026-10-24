import AVKit
import PhotosUI
import SwiftUI
import UIKit

struct PostComposerSheet: View {
    let model: HomeViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedMedia: PickedMediaFile?
    @State private var mediaLoadID = UUID()
    @State private var isLoadingMedia = false
    @State private var isSubmitting = false
    @State private var hasMediaError = false
    @State private var hasMediaSizeError = false
    @State private var hasSubmitError = false
    @FocusState private var captionFocused: Bool

    private var trimmedCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("post.create.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("post.create.caption", text: $caption, axis: .vertical)
                        .lineLimit(5...10)
                        .padding(14)
                        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .focused($captionFocused)

                    PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                        Label("post.create.addMedia", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    if isLoadingMedia {
                        ProgressView("post.create.loadingMedia")
                            .frame(maxWidth: .infinity)
                    } else if let selectedMedia {
                        mediaPreview(selectedMedia)
                    }

                    if hasMediaError {
                        Text(LocalizedStringKey(hasMediaSizeError ? "post.create.mediaTooLarge" : "post.create.mediaError"))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if hasSubmitError {
                        Text("post.create.submitError")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(18)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("post.create.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("post.create.publish") { publish() }
                        .disabled(isSubmitting || isLoadingMedia || (trimmedCaption.isEmpty && selectedMedia == nil))
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else {
                    mediaLoadID = UUID()
                    removeTemporaryMedia()
                    selectedMedia = nil
                    isLoadingMedia = false
                    hasMediaError = false
                    hasMediaSizeError = false
                    return
                }
                loadMedia(newItem)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            mediaLoadID = UUID()
            removeTemporaryMedia()
        }
    }

    @ViewBuilder
    private func mediaPreview(_ media: PickedMediaFile) -> some View {
        if media.kind == .video {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GlintPalette.surface.gradient)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 36))
                        Text("post.create.videoSelected")
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(height: 180)
        } else if let image = UIImage(contentsOfFile: media.fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func loadMedia(_ item: PhotosPickerItem) {
        let loadID = UUID()
        mediaLoadID = loadID
        removeTemporaryMedia()
        selectedMedia = nil
        isLoadingMedia = true
        hasMediaError = false
        hasMediaSizeError = false

        Task {
            defer {
                if mediaLoadID == loadID { isLoadingMedia = false }
            }
            do {
                let importedMedia = try await item.loadTransferable(type: PickedMediaFile.self)
                guard mediaLoadID == loadID else {
                    if let importedMedia { try? FileManager.default.removeItem(at: importedMedia.fileURL) }
                    return
                }
                guard let importedMedia else {
                    hasMediaError = true
                    return
                }
                selectedMedia = importedMedia
            } catch MediaImportError.fileTooLarge {
                if mediaLoadID == loadID {
                    hasMediaError = true
                    hasMediaSizeError = true
                }
            } catch {
                if mediaLoadID == loadID { hasMediaError = true }
            }
        }
    }

    private func publish() {
        guard !isSubmitting else { return }
        isSubmitting = true
        hasSubmitError = false
        Task {
            defer { isSubmitting = false }
            var storedMediaURL: URL?
            do {
                var media: [PostMedia] = []
                if let selectedMedia {
                    let storedMedia = try persistMedia(selectedMedia)
                    storedMediaURL = storedMedia.localFileURL
                    media = [storedMedia]
                }
                try await model.createPost(caption: trimmedCaption, media: media)
                removeTemporaryMedia()
                dismiss()
            } catch {
                if let storedMediaURL { try? FileManager.default.removeItem(at: storedMediaURL) }
                hasSubmitError = true
            }
        }
    }

    private func persistMedia(_ picked: PickedMediaFile) throws -> PostMedia {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GlintUploads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = picked.fileURL.pathExtension.isEmpty ? (picked.kind == .video ? "mov" : "jpg") : picked.fileURL.pathExtension
        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: picked.fileURL, to: fileURL)
        return PostMedia(
            kind: picked.kind,
            localFileURL: fileURL,
            accessibilityDescription: trimmedCaption
        )
    }

    private func removeTemporaryMedia() {
        guard let url = selectedMedia?.fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
