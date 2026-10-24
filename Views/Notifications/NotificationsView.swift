import SwiftUI

private struct NotificationRoute: Identifiable {
    enum Kind: String { case profile, post }
    let kind: Kind
    let targetID: UUID
    var id: String { "\(kind.rawValue)-\(targetID.uuidString)" }
}

@MainActor
struct NotificationsView: View {
    let viewerID: UUID
    let services: GlintServices
    let onUnreadCountChanged: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: NotificationsViewModel
    @State private var route: NotificationRoute?

    init(viewerID: UUID, services: GlintServices, onUnreadCountChanged: @escaping (Int) -> Void) {
        self.viewerID = viewerID
        self.services = services
        self.onUnreadCountChanged = onUnreadCountChanged
        _model = State(initialValue: NotificationsViewModel(viewerID: viewerID, services: services))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    GlintLoadingState(lineCount: 6)
                case .failed:
                    GlintErrorState(
                        title: "notifications.error.title",
                        message: LocalizedStringKey(model.errorKey ?? "notifications.error.load"),
                        retryTitle: "auth.retry.button",
                        retry: { Task { await model.load() } }
                    )
                case .empty:
                    GlintEmptyState(systemImage: "bell", title: "notifications.empty.title", message: "notifications.empty.message")
                case .ready:
                    notificationList
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("notifications.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if model.unreadCount > 0 || model.isMarkingAllRead {
                        Button {
                            Task {
                                await model.markAllAsRead()
                                onUnreadCountChanged(model.unreadCount)
                            }
                        } label: {
                            if model.isMarkingAllRead { ProgressView() }
                            else { Text("notifications.markAllRead") }
                        }
                        .disabled(model.isMarkingAllRead || model.isUpdatingReadStatus)
                        .accessibilityLabel(Text("notifications.markAllRead"))
                    }
                }
            }
            .sheet(item: $route) { destination in
                switch destination.kind {
                case .profile:
                    OtherProfileView(profileID: destination.targetID, viewerID: viewerID, services: services) {
                        Task {
                            await model.refresh()
                            onUnreadCountChanged(model.unreadCount)
                        }
                    }
                case .post:
                    NotificationPostSheet(postID: destination.targetID, viewerID: viewerID, services: services) {
                        Task {
                            await model.refresh()
                            onUnreadCountChanged(model.unreadCount)
                        }
                    }
                }
            }
            .task {
                await model.load()
                onUnreadCountChanged(model.unreadCount)
            }
            .onChange(of: model.unreadCount) { _, count in onUnreadCountChanged(count) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                if let errorKey = model.errorKey {
                    Text(LocalizedStringKey(errorKey))
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                ForEach(model.notifications) { notification in
                    notificationRow(notification)
                        .task { await model.loadMoreIfNeeded(current: notification) }
                }
                if model.isLoadingMore {
                    ProgressView().tint(GlintPalette.accent).padding()
                }
                if let errorKey = model.paginationErrorKey {
                    VStack(spacing: 8) {
                        Text(LocalizedStringKey(errorKey)).font(.footnote).foregroundStyle(.secondary)
                        Button("home.pagination.retry", systemImage: "arrow.clockwise") {
                            Task { await model.retryLoadMore() }
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(14)
                }
            }
            .padding(14)
        }
        .refreshable {
            await model.refresh()
            onUnreadCountChanged(model.unreadCount)
        }
    }

    private func notificationRow(_ notification: GlintNotification) -> some View {
        Button {
            Task {
                let didPrepareToOpen = await model.markAsRead(notification)
                guard didPrepareToOpen else { return }
                onUnreadCountChanged(model.unreadCount)
                switch notification.destination {
                case .profile(let userID): route = NotificationRoute(kind: .profile, targetID: userID)
                case .post(let postID): route = NotificationRoute(kind: .post, targetID: postID)
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                if let actor = model.actorsByID[notification.actorID] {
                    GlintAvatarView(user: actor, size: 48)
                } else {
                    Circle().fill(GlintPalette.surface).frame(width: 48, height: 48)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    eventMessage(notification)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(notification.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !notification.isRead {
                    Circle()
                        .fill(GlintPalette.accent)
                        .frame(width: 9, height: 9)
                        .accessibilityLabel(Text("notifications.unread"))
                }
            }
            .padding(13)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isMarkingAllRead || model.isUpdatingReadStatus)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("notifications.open.hint"))
    }

    @ViewBuilder
    private func eventMessage(_ notification: GlintNotification) -> some View {
        let actorName = model.actorsByID[notification.actorID]?.displayName ?? "Glint"
        switch notification.event {
        case .like:
            HStack(spacing: 4) {
                Text(verbatim: actorName).fontWeight(.semibold)
                Text("notifications.action.like")
            }
        case .comment(let text):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(verbatim: actorName).fontWeight(.semibold)
                    Text("notifications.action.comment")
                }
                Text("“\(text)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .newFollower:
            HStack(spacing: 4) {
                Text(verbatim: actorName).fontWeight(.semibold)
                Text("notifications.action.follow")
            }
        }
    }
}

@MainActor
private struct NotificationPostSheet: View {
    let postID: UUID
    let viewerID: UUID
    let services: GlintServices
    let onBlocked: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var post: GlintPost?
    @State private var author: GlintUser?
    @State private var profileRoute: NotificationRoute?
    @State private var showComments = false
    @State private var isLoading = true
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    GlintLoadingState(lineCount: 4)
                } else if let errorKey {
                    GlintErrorState(
                        title: "notifications.post.error.title",
                        message: LocalizedStringKey(errorKey),
                        retryTitle: "auth.retry.button",
                        retry: { Task { await load() } }
                    )
                } else if let post, let author {
                    postContent(post, author: author)
                } else {
                    GlintEmptyState(systemImage: "square.grid.3x3", title: "notifications.post.error.title", message: "notifications.post.error.load")
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("notifications.post.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showComments) {
                if let post {
                    PostCommentsSheet(post: post, viewerID: viewerID, services: services) {
                        self.post?.commentCount += 1
                    }
                }
            }
            .sheet(item: $profileRoute) { route in
                OtherProfileView(profileID: route.targetID, viewerID: viewerID, services: services) {
                    onBlocked()
                    dismiss()
                }
            }
            .task { await load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func postContent(_ post: GlintPost, author: GlintUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button { profileRoute = NotificationRoute(kind: .profile, targetID: author.id) } label: {
                    HStack(spacing: 10) {
                        GlintAvatarView(user: author, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(author.displayName).font(.subheadline.weight(.semibold))
                            Text("@\(author.username)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let media = post.media.first { GlintMediaView(media: media) }
                if !post.caption.isEmpty {
                    Text(post.caption).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 20) {
                    Button {
                        Task { await toggleLike(post) }
                    } label: {
                        Label(post.likeCount.formatted(), systemImage: post.isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(post.isLiked ? GlintPalette.accent : Color.primary)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(LocalizedStringKey(post.isLiked ? "post.unlike" : "post.like"))
                    Button { showComments = true } label: {
                        Label(post.commentCount.formatted(), systemImage: "bubble.right")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text("post.comment"))
                }
            }
            .padding(16)
            .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorKey = nil
        defer { isLoading = false }
        do {
            let loaded = try await services.posts.fetchPost(postID, for: viewerID)
            var loadedAuthor = try await services.users.fetchUser(id: loaded.authorID, viewedBy: viewerID)
            if services.subscriptions is MockSubscriptionService {
                let tier = try await services.subscriptions.currentTier(for: loaded.authorID)
                if tier != .glintPlus { loadedAuthor.avatarShape = .circle }
            }
            post = loaded
            author = loadedAuthor
        } catch {
            errorKey = "notifications.post.error.load"
        }
    }

    @MainActor
    private func toggleLike(_ current: GlintPost) async {
        var optimistic = current
        optimistic.isLiked.toggle()
        optimistic.likeCount = max(0, optimistic.likeCount + (optimistic.isLiked ? 1 : -1))
        post = optimistic
        do {
            post = try await services.posts.toggleLike(postID: current.id, by: viewerID)
        } catch {
            post = current
            errorKey = "notifications.post.error.like"
        }
    }
}
