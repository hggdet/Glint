import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct EditProfileView: View {
    let user: GlintUser
    @Bindable var model: ProfileViewModel
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var username: String
    @State private var displayName: String
    @State private var bio: String
    @State private var avatarShape: AvatarShape
    @State private var avatarAssetName: String?
    @State private var bannerAssetName: String?
    @State private var bannerMediaKind: PostMediaKind?
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var selectedAvatar: PickedMediaFile?
    @State private var selectedBanner: PickedMediaFile?
    @State private var isLoadingMedia = false
    @State private var isShowingPlus = false
    @State private var isSaving = false
    @State private var shouldRemoveBanner = false
    @State private var errorKey: String?
    @State private var loadID = UUID()

    init(user: GlintUser, model: ProfileViewModel, onSaved: @escaping () -> Void) {
        self.user = user
        self.model = model
        self.onSaved = onSaved
        _username = State(initialValue: user.username)
        _displayName = State(initialValue: user.displayName)
        _bio = State(initialValue: user.bio)
        _avatarShape = State(initialValue: model.tier == .glintPlus ? user.avatarShape : .circle)
        _avatarAssetName = State(initialValue: user.avatarAssetName)
        _bannerAssetName = State(initialValue: user.bannerAssetName)
        _bannerMediaKind = State(initialValue: user.bannerMediaKind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    avatarSection
                    textFields
                    bannerSection
                    shapeSection
                    if let errorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(18)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("profile.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(isSaving || isLoadingMedia)
                }
            }
            .onChange(of: avatarItem) { _, item in
                if let item { load(item, forAvatar: true) }
            }
            .onChange(of: bannerItem) { _, item in
                if let item { load(item, forAvatar: false) }
            }
        }
        .sheet(isPresented: $isShowingPlus) {
            GlintPlusSheet(model: model)
        }
        .onDisappear {
            guard !isShowingPlus else { return }
            loadID = UUID()
            removeTemporarySelection(selectedAvatar)
            removeTemporarySelection(selectedBanner)
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            avatarPreview(size: 96)
            PhotosPicker(selection: $avatarItem, matching: .images) {
                Label("profile.photo.change", systemImage: "camera")
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("profile.displayName") {
                TextField("profile.displayName", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("profile.username") {
                TextField("profile.username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("profile.bio").font(.subheadline.weight(.semibold))
                TextField("profile.bio.placeholder", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(14)
        .background(GlintPalette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.banner.title").font(.headline)
            bannerPreview
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            PhotosPicker(selection: $bannerItem, matching: .any(of: [.images, .videos])) {
                Label("profile.banner.choose", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            Button("profile.banner.remove", role: .destructive) {
                removeTemporarySelection(selectedBanner)
                selectedBanner = nil
                bannerAssetName = nil
                bannerMediaKind = nil
                shouldRemoveBanner = true
            }
            .font(.footnote)
        }
    }

    @ViewBuilder
    private var bannerPreview: some View {
        if let selectedBanner, selectedBanner.kind == .video {
            ProfileBannerVideoView(url: selectedBanner.fileURL)
        } else if let selectedBanner,
                  selectedBanner.kind == .photo,
                  let image = UIImage(contentsOfFile: selectedBanner.fileURL.path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let asset = bannerAssetName, let image = UIImage(named: asset) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [GlintPalette.accent, GlintPalette.secondaryAccent, GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("profile.avatarShape.title").font(.headline)
                Spacer()
                if model.tier == .glintPlus {
                    Label("plus.active", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlintPalette.accent)
                } else {
                    Button("plus.title") { isShowingPlus = true }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(AvatarShape.allCases) { shape in
                    Button {
                        guard shape.requiresGlintPlus else {
                            avatarShape = shape
                            return
                        }
                        guard model.tier == .glintPlus else {
                            isShowingPlus = true
                            return
                        }
                        avatarShape = shape
                    } label: {
                        VStack(spacing: 7) {
                            avatarPreview(size: 54, shape: shape)
                            HStack(spacing: 4) {
                                Text(shapeTitle(shape)).font(.caption2)
                                if shape.requiresGlintPlus {
                                    Image(systemName: "sparkles").font(.caption2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(avatarShape == shape ? GlintPalette.accent.opacity(0.13) : GlintPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(avatarShape == shape ? GlintPalette.accent : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(shapeTitle(shape))
                    .accessibilityAddTraits(avatarShape == shape ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func avatarPreview(size: CGFloat, shape: AvatarShape? = nil) -> some View {
        let previewUser = GlintUser(
            id: user.id,
            username: user.username,
            displayName: displayName.isEmpty ? user.displayName : displayName,
            avatarAssetName: selectedAvatar == nil ? avatarAssetName : nil,
            avatarFileURL: selectedAvatar?.fileURL ?? user.avatarFileURL,
            avatarShape: shape ?? avatarShape
        )
        GlintAvatarView(user: previewUser, size: size)
    }

    private func shapeTitle(_ shape: AvatarShape) -> LocalizedStringKey {
        switch shape {
        case .circle: return "profile.shape.circle"
        case .roundedSquare: return "profile.shape.roundedSquare"
        case .squircle: return "profile.shape.squircle"
        case .star: return "profile.shape.star"
        case .hexagon: return "profile.shape.hexagon"
        }
    }

    private func load(_ item: PhotosPickerItem, forAvatar: Bool) {
        let currentLoadID = UUID()
        loadID = currentLoadID
        isLoadingMedia = true
        errorKey = nil
        Task {
            defer { if loadID == currentLoadID { isLoadingMedia = false } }
            do {
                let imported = try await item.loadTransferable(type: PickedMediaFile.self)
                guard loadID == currentLoadID else {
                    removeTemporarySelection(imported)
                    return
                }
                guard let imported else {
                    errorKey = "profile.error.mediaImport"
                    return
                }
                if forAvatar && imported.kind != .photo {
                    removeTemporarySelection(imported)
                    errorKey = "profile.error.imageOnly"
                    return
                }
                if forAvatar {
                    removeTemporarySelection(selectedAvatar)
                    selectedAvatar = imported
                    avatarAssetName = nil
                } else {
                    removeTemporarySelection(selectedBanner)
                    selectedBanner = imported
                    bannerAssetName = nil
                    bannerMediaKind = imported.kind
                    shouldRemoveBanner = false
                }
            } catch MediaImportError.fileTooLarge {
                errorKey = "profile.error.mediaTooLarge"
            } catch {
                errorKey = "profile.error.mediaImport"
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        guard normalizedUsername.range(of: #"^[a-z0-9._]{3,20}$"#, options: .regularExpression) != nil else {
            errorKey = "profile.error.invalidUsername"
            return
        }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorKey = "profile.error.displayNameRequired"
            return
        }
        isSaving = true
        errorKey = nil
        Task {
            var newFiles: [URL] = []
            do {
                let avatarFileURL = try persist(selectedAvatar, oldURL: user.avatarFileURL, to: &newFiles)
                let bannerFileURL = shouldRemoveBanner ? nil : try persist(selectedBanner, oldURL: user.bannerFileURL, to: &newFiles)
                let update = ProfileUpdate(
                    username: username,
                    displayName: displayName,
                    bio: bio,
                    avatarAssetName: selectedAvatar == nil ? avatarAssetName : nil,
                    avatarFileURL: avatarFileURL,
                    bannerAssetName: selectedBanner == nil && !shouldRemoveBanner ? bannerAssetName : nil,
                    bannerFileURL: bannerFileURL,
                    bannerMediaKind: selectedBanner?.kind ?? (shouldRemoveBanner ? nil : bannerMediaKind),
                    avatarShape: avatarShape,
                    isPrivate: user.isPrivate
                )
                try await model.updateProfile(update)
                removeTemporarySelection(selectedAvatar)
                removeTemporarySelection(selectedBanner)
                removeReplacedFile(old: user.avatarFileURL, new: avatarFileURL)
                removeReplacedFile(old: user.bannerFileURL, new: bannerFileURL)
                onSaved()
                dismiss()
            } catch {
                for url in newFiles { try? FileManager.default.removeItem(at: url) }
                errorKey = profileErrorKey(for: error)
            }
            isSaving = false
        }
    }

    private func persist(_ selected: PickedMediaFile?, oldURL: URL?, to created: inout [URL]) throws -> URL? {
        guard let selected else { return oldURL }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GlintProfile", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = selected.fileURL.pathExtension.isEmpty ? (selected.kind == .video ? "mov" : "jpg") : selected.fileURL.pathExtension
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: selected.fileURL, to: destination)
        created.append(destination)
        return destination
    }

    private func removeTemporarySelection(_ selected: PickedMediaFile?) {
        guard let url = selected?.fileURL,
              url.deletingLastPathComponent() == FileManager.default.temporaryDirectory else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func removeReplacedFile(old: URL?, new: URL?) {
        guard let old, old != new,
              old.path.contains("/GlintProfile/") else { return }
        try? FileManager.default.removeItem(at: old)
    }

    private func profileErrorKey(for error: Error) -> String {
        if let serviceError = error as? GlintServiceError {
            switch serviceError {
            case .glintPlusRequired: return "profile.error.plusRequired"
            case .usernameUnavailable: return "profile.error.usernameTaken"
            case .invalidUsername: return "profile.error.invalidUsername"
            case .emptyDisplayName: return "profile.error.displayNameRequired"
            default: break
            }
        }
        return "profile.error.generic"
    }
}
