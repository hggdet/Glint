import SwiftUI
import UIKit

private enum OtherProfileDestination: String, Identifiable, Equatable {
    case report
    case followers
    case following
    var id: String { rawValue }
}

@MainActor
struct OtherProfileView: View {
    let profileID: UUID
    let viewerID: UUID
    let services: GlintServices
    var onBlocked: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var model: OtherProfileViewModel
    @State private var activeSheet: OtherProfileDestination?
    @State private var isConfirmingBlock = false

    init(profileID: UUID, viewerID: UUID, services: GlintServices, onBlocked: @escaping () -> Void = {}) {
        self.profileID = profileID
        self.viewerID = viewerID
        self.services = services
        self.onBlocked = onBlocked
        _model = State(initialValue: OtherProfileViewModel(profileID: profileID, viewerID: viewerID, services: services))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    GlintLoadingState(lineCount: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed:
                    GlintErrorState(
                        title: "profile.other.error.title",
                        message: LocalizedStringKey(model.errorKey ?? "profile.other.error.unavailable"),
                        retryTitle: "auth.retry.button",
                        retry: { Task { await model.retry() } }
                    )
                case .ready:
                    profileContent
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle(model.user.map { Text(verbatim: "@\($0.username)") } ?? Text("profile.other.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if profileID != viewerID {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("profile.other.report", systemImage: "flag") { activeSheet = .report }
                            Button("profile.other.block", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                                isConfirmingBlock = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel(Text("profile.other.actions"))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.done") { dismiss() }
                        .buttonStyle(.glass)
                }
            }
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .report:
                    PostReportSheet { reason, note in try await model.report(reason, note: note) }
                case .followers, .following:
                    FollowListSheet(
                        userID: profileID,
                        viewerID: viewerID,
                        kind: destination == .followers ? .followers : .following,
                        services: services
                    )
                }
            }
            .confirmationDialog("profile.other.block.confirm.title", isPresented: $isConfirmingBlock, titleVisibility: .visible) {
                Button("profile.other.block", role: .destructive) {
                    Task {
                        if await model.block() {
                            onBlocked()
                            dismiss()
                        }
                    }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("profile.other.block.confirm.message")
            }
            .task { await model.load() }
        }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = model.user {
                    banner(user)
                        .frame(height: 172)
                        .overlay(alignment: .bottomLeading) {
                            GlintAvatarView(user: displayedUser(user), size: 90)
                                .offset(y: 38)
                                .padding(.leading, 20)
                        }
                        .padding(.bottom, 30)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(user.displayName).font(.title2.bold())
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(GlintPalette.accent)
                                    .accessibilityLabel(Text("profile.verified"))
                            }
                        }
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !user.bio.isEmpty { Text(user.bio).padding(.top, 4) }
                        if profileID != viewerID {
                            followButton.padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)

                    stats(user)

                    if let errorKey = model.errorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 18)
                    }
                    if let noticeKey = model.noticeKey {
                        Text(LocalizedStringKey(noticeKey))
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 18)
                    }

                    if model.canViewPosts {
                        postsGrid
                    } else {
                        GlintEmptyState(
                            systemImage: "lock.fill",
                            title: model.followStatus == .pending ? "profile.other.private.pending.title" : "profile.other.private.title",
                            message: model.followStatus == .pending ? "profile.other.private.pending.message" : "profile.other.private.message"
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private var followButton: some View {
        if model.followStatus == .accepted {
            Button { Task { await model.toggleFollow() } } label: { followButtonContent }
                .buttonStyle(.glass)
                .disabled(model.isChangingFollow)
                .accessibilityHint(Text("profile.other.follow.hint"))
        } else {
            Button { Task { await model.toggleFollow() } } label: { followButtonContent }
                .buttonStyle(.glassProminent)
                .disabled(model.isChangingFollow)
                .accessibilityHint(Text("profile.other.follow.hint"))
        }
    }

    private var followButtonContent: some View {
        HStack {
            if model.isChangingFollow { ProgressView().tint(.white) }
            Text(followButtonTitle)
        }
        .frame(maxWidth: .infinity)
    }

    private var followButtonTitle: LocalizedStringKey {
        switch model.followStatus {
        case .accepted: return "profile.other.unfollow"
        case .pending: return "profile.other.follow.cancelRequest"
        case .rejected, .none: return "profile.other.follow"
        }
    }

    private func stats(_ user: GlintUser) -> some View {
        HStack(spacing: 0) {
            stat(value: user.postCount, title: "profile.posts", destination: nil)
            stat(value: user.followerCount, title: "profile.followers", destination: .followers)
            stat(value: user.followingCount, title: "profile.following", destination: .following)
        }
        .padding(.vertical, 14)
        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func stat(value: Int, title: LocalizedStringKey, destination: OtherProfileDestination?) -> some View {
        Group {
            if let destination {
                Button { activeSheet = destination } label: { statContent(value: value, title: title) }
                    .buttonStyle(.plain)
                    .disabled(userListIsPrivate)
            } else {
                statContent(value: value, title: title)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statContent(value: Int, title: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(value.formatted()).font(.headline.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var userListIsPrivate: Bool {
        model.user?.isPrivate == true && !model.canViewPosts
    }

    private var postsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.posts").font(.headline).padding(.horizontal, 18)
            if model.posts.isEmpty {
                GlintEmptyState(systemImage: "square.grid.3x3", title: "profile.posts.empty.title", message: "profile.posts.empty.message")
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(model.posts) { post in
                        Group {
                            if let media = post.media.first, media.kind == .photo {
                                GlintMediaView(media: media, cornerRadius: 0)
                            } else {
                                Rectangle()
                                    .fill(LinearGradient(colors: [GlintPalette.accent.opacity(0.7), GlintPalette.secondaryAccent.opacity(0.6), GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(Image(systemName: post.containsVideo ? "play.fill" : "text.alignleft").foregroundStyle(.white))
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel(Text(verbatim: post.caption.isEmpty ? "Glint post" : post.caption))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func banner(_ user: GlintUser) -> some View {
        if user.bannerMediaKind == .video, let url = bannerVideoURL(user) {
            ProfileBannerVideoView(url: url, isActive: activeSheet == nil && !isConfirmingBlock)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
        } else if let image = bannerImage(user) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
                .accessibilityLabel(Text("profile.banner.image"))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [GlintPalette.accent.opacity(0.85), GlintPalette.secondaryAccent.opacity(0.6), GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.horizontal, 16)
        }
    }

    private func bannerVideoURL(_ user: GlintUser) -> URL? {
        if let url = user.bannerFileURL { return url }
        guard let name = user.bannerAssetName else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Media")
            ?? Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Resources/Media")
            ?? Bundle.main.url(forResource: name, withExtension: "mp4")
    }

    private func bannerImage(_ user: GlintUser) -> UIImage? {
        if let url = user.bannerFileURL, let image = UIImage(contentsOfFile: url.path) { return image }
        if let name = user.bannerAssetName { return UIImage(named: name) }
        return nil
    }

    private func displayedUser(_ user: GlintUser) -> GlintUser {
        var result = user
        if model.shouldGateAvatarShapeLocally && model.tier != .glintPlus { result.avatarShape = .circle }
        return result
    }
}
