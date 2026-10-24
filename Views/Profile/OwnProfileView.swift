import SwiftUI
import UIKit

private enum ProfileDestination: String, Identifiable, Equatable {
    case edit
    case plus
    case followers
    case following
    var id: String { rawValue }
}

@MainActor
struct OwnProfileView: View {
    @Bindable var model: ProfileViewModel
    let isTabActive: Bool
    var onProfileUpdated: () -> Void = {}
    @State private var destination: ProfileDestination?

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    GlintLoadingState(lineCount: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed:
                    GlintErrorState(
                        title: "profile.error.title",
                        message: model.errorKey.map(LocalizedStringKey.init) ?? "profile.error.generic",
                        retryTitle: "auth.retry.button",
                        retry: { Task { await model.retry() } }
                    )
                case .ready:
                    profileContent
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("tab.profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                profileToolbarContent
            }
            .sheet(item: $destination) { page in
                switch page {
                case .edit:
                    if let user = model.user {
                        EditProfileView(user: user, model: model, onSaved: onProfileUpdated)
                    }
                case .plus:
                    GlintPlusSheet(model: model)
                case .followers:
                    FollowListSheet(userID: model.viewerID, viewerID: model.viewerID, kind: .followers, services: model.servicesForLists)
                case .following:
                    FollowListSheet(userID: model.viewerID, viewerID: model.viewerID, kind: .following, services: model.servicesForLists)
                }
            }
            .task(id: isTabActive) {
                guard isTabActive else { return }
                if model.state == .ready { await model.refresh() }
                else { await model.load() }
            }
        }
    }

    @ToolbarContentBuilder
    private var profileToolbarContent: some ToolbarContent {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { destination = .plus } label: {
                        Label("plus.title", systemImage: "sparkles")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text("plus.title"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { destination = .edit } label: {
                        Label("profile.edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text("profile.edit"))
                }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let user = model.user {
                    profileHeader(displayedUser(user))
                    profileStats(user)
                    if !model.followRequests.isEmpty { followRequestsSection }
                    if let errorKey = model.errorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let noticeKey = model.noticeKey {
                        Text(LocalizedStringKey(noticeKey))
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    postSection
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private func profileHeader(_ user: GlintUser) -> some View {
        VStack(alignment: .leading, spacing: 15) {
                    banner(for: user)
                        .frame(height: 172)
                        .overlay(alignment: .bottomLeading) {
                            GlintAvatarView(user: user, size: 90)
                            .offset(y: 38)
                            .padding(.leading, 20)
                }
                .padding(.bottom, 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(user.displayName).font(.title2.weight(.bold))
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(GlintPalette.accent)
                            .accessibilityLabel(Text("profile.verified"))
                    }
                    if model.tier == .glintPlus {
                        Label("plus.active", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GlintPalette.accent)
                    }
                }
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.body)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func banner(for user: GlintUser) -> some View {
        if user.bannerMediaKind == .video, let url = bannerVideoURL(user) {
            ProfileBannerVideoView(url: url, isActive: isTabActive && destination == nil)
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
                .fill(LinearGradient(colors: [GlintPalette.accent.opacity(0.85), GlintPalette.secondaryAccent.opacity(0.62), GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(22)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .accessibilityLabel(Text("profile.banner.image"))
        }
    }

    private func bannerVideoURL(_ user: GlintUser) -> URL? {
        if let fileURL = user.bannerFileURL { return fileURL }
        guard let assetName = user.bannerAssetName else { return nil }
        return Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Media")
            ?? Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Resources/Media")
            ?? Bundle.main.url(forResource: assetName, withExtension: "mp4")
    }

    private func bannerImage(_ user: GlintUser) -> UIImage? {
        if let fileURL = user.bannerFileURL, let image = UIImage(contentsOfFile: fileURL.path) { return image }
        if let assetName = user.bannerAssetName { return UIImage(named: assetName) }
        return nil
    }

    private func displayedUser(_ user: GlintUser) -> GlintUser {
        var displayed = user
        if model.tier != .glintPlus { displayed.avatarShape = .circle }
        return displayed
    }

    private func profileStats(_ user: GlintUser) -> some View {
        HStack(spacing: 0) {
            stat(value: model.posts.count, title: "profile.posts")
            stat(value: user.followerCount, title: "profile.followers") { destination = .followers }
            stat(value: user.followingCount, title: "profile.following") { destination = .following }
        }
        .padding(.vertical, 14)
        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var followRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.followRequests.title")
                .font(.headline)
                .padding(.horizontal, 18)
            ForEach(model.followRequests) { request in
                if let requester = model.requestersByID[request.requesterID] {
                    HStack(spacing: 10) {
                        GlintAvatarView(user: requester, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(requester.displayName).font(.subheadline.weight(.semibold))
                            Text("@\(requester.username)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button("profile.followRequests.accept") {
                            Task { await model.respondToFollowRequest(request, accept: true) }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(model.respondingToRequestID != nil)
                        Button("profile.followRequests.reject") {
                            Task { await model.respondToFollowRequest(request, accept: false) }
                        }
                        .buttonStyle(.glass)
                        .disabled(model.respondingToRequestID != nil)
                    }
                    .padding(12)
                    .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func stat(value: Int, title: LocalizedStringKey, action: (() -> Void)? = nil) -> some View {
        let content = VStack(spacing: 3) {
            Text(value.formatted()).font(.headline.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        return Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else { content }
        }
    }

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.posts")
                .font(.headline)
                .padding(.horizontal, 18)
            if model.posts.isEmpty {
                GlintEmptyState(systemImage: "square.grid.3x3", title: "profile.posts.empty.title", message: "profile.posts.empty.message")
                    .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(model.posts) { post in
                        ProfilePostTile(post: post)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

private struct ProfilePostTile: View {
    let post: GlintPost

    var body: some View {
        Group {
            if let media = post.media.first {
                if media.kind == .video {
                    Rectangle()
                        .fill(LinearGradient(colors: [GlintPalette.accent.opacity(0.72), GlintPalette.secondaryAccent.opacity(0.58), GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                } else {
                    GlintMediaView(media: media, cornerRadius: 0)
                        .clipped()
                }
            } else {
                Rectangle()
                    .fill(GlintPalette.surface.gradient)
                    .overlay {
                        Image(systemName: "text.alignleft")
                            .font(.title2)
                            .foregroundStyle(GlintPalette.accent)
                    }
            }
        }
        .accessibilityLabel(Text(verbatim: post.caption.isEmpty ? "Glint post" : post.caption))
    }
}
