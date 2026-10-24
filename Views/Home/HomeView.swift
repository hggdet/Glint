import SwiftUI

private enum HomeSheet: String, Identifiable {
    case composer
    case search
    case notifications
    case profile
    var id: String { rawValue }
}

struct HomeView: View {
    @Bindable var model: HomeViewModel
    let services: GlintServices

    @State private var activeSheet: HomeSheet?
    @State private var selectedProfile: GlintUser?

    private var notificationsAccessibilityLabel: LocalizedStringKey {
        model.unreadNotificationCount > 0 ? "home.notifications.unread" : "home.notifications"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !model.stories.isEmpty {
                        StoryOvalView(
                        stories: model.stories,
                        authorsByID: model.authorsByID,
                        viewerID: model.viewerID,
                        services: services,
                        onSeen: { item in await model.markStorySeen(item) }
                        )
                    }

                    switch model.state {
                    case .loading:
                        GlintLoadingState(lineCount: 4)
                    case .empty:
                        GlintEmptyState(
                            systemImage: "person.2",
                            title: "home.feed.empty.title",
                            message: "home.feed.empty.message"
                        )
                    case .failed:
                        GlintErrorState(
                            title: "home.error.title",
                            message: "home.error.message",
                            retryTitle: "auth.retry.button",
                            retry: { Task { await model.load() } }
                        )
                    case .ready:
                        feed
                    }

                    if let errorKey = model.errorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .refreshable { await model.refresh() }
            .navigationTitle("app.name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { activeSheet = .composer } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel(Text("home.createPost"))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { activeSheet = .search } label: {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text("home.search"))

                    Button { activeSheet = .notifications } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .frame(width: 44, height: 44)
                            if model.unreadNotificationCount > 0 {
                                Text(model.unreadNotificationCount > 99 ? "99+" : model.unreadNotificationCount.formatted())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(GlintPalette.accent, in: Capsule())
                                    .overlay(Capsule().stroke(GlintPalette.background, lineWidth: 1.5))
                                    .offset(x: -1, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text(notificationsAccessibilityLabel))
                    .accessibilityValue(model.unreadNotificationCount.formatted())
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .composer:
                    PostComposerSheet(model: model)
                case .search:
                    SearchView(viewerID: model.viewerID, services: services)
                case .notifications:
                    NotificationsView(viewerID: model.viewerID, services: services) { count in
                        model.updateUnreadNotificationCount(count)
                    }
                case .profile:
                    if let selectedProfile {
                        OtherProfileView(profileID: selectedProfile.id, viewerID: model.viewerID, services: services) {
                            Task { await model.load() }
                        }
                    } else {
                        HomePlaceholderSheet(title: "profile.other.title", symbol: "person.crop.circle")
                    }
                }
            }
        }
    }

    private var feed: some View {
        LazyVStack(spacing: 16) {
            ForEach(model.posts) { post in
                if let author = model.authorsByID[post.authorID] {
                    GlintPostCard(
                        post: post,
                        author: author,
                        viewModel: model,
                        services: services,
                        onOpenProfile: { user in
                            selectedProfile = user
                            activeSheet = .profile
                        }
                    )
                    .task { await model.loadMoreIfNeeded(currentPost: post) }
                }
            }
            if model.isLoadingMore {
                ProgressView().tint(GlintPalette.accent).padding()
            }
            if let paginationErrorKey = model.paginationErrorKey {
                VStack(spacing: 8) {
                    Text(LocalizedStringKey(paginationErrorKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("home.pagination.retry", systemImage: "arrow.clockwise") {
                        Task { await model.retryLoadMore() }
                    }
                    .buttonStyle(.glass)
                    .disabled(model.isLoadingMore)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct HomePlaceholderSheet: View {
    let title: LocalizedStringKey
    let symbol: String
    var subtitle: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                GlintEmptyState(systemImage: symbol, title: title, message: "app.section.comingSoon")
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
