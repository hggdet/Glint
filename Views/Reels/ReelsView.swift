import SwiftUI
import UIKit

private enum ReelSheet: Identifiable {
    case comments(GlintPost)
    case share(GlintPost)
    case report(GlintPost)

    var id: String {
        switch self {
        case .comments(let post): return "comments-\(post.id.uuidString)"
        case .share(let post): return "share-\(post.id.uuidString)"
        case .report(let post): return "report-\(post.id.uuidString)"
        }
    }
}

@MainActor
struct ReelsView: View {
    @Bindable var model: ReelsViewModel
    let services: GlintServices
    let isTabActive: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSheet: ReelSheet?
    @State private var activeReelID: UUID?
    @State private var unmutedReelIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.state {
            case .loading:
                GlintLoadingState(lineCount: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.colorScheme, .dark)
            case .empty:
                GlintEmptyState(
                    systemImage: "play.rectangle",
                    title: "reels.empty.title",
                    message: "reels.empty.message"
                )
                .environment(\.colorScheme, .dark)
            case .failed:
                GlintErrorState(
                    title: "reels.error.title",
                    message: "reels.error.load",
                    retryTitle: "auth.retry.button",
                    retry: { Task { await model.load() } }
                )
                .environment(\.colorScheme, .dark)
            case .ready:
                reelPager
            }
        }
        .background(.black)
        .statusBarHidden(model.state == .ready)
        .task(id: isTabActive && scenePhase == .active) {
            guard isTabActive, scenePhase == .active else { return }
            await model.load()
        }
        .onChange(of: isTabActive) { _, isActive in
            if !isActive { activeSheet = nil }
        }
        .onChange(of: model.reels.map(\.id)) { _, reelIDs in
            if let activeReelID, !reelIDs.contains(activeReelID) {
                self.activeReelID = reelIDs.first
            } else if activeReelID == nil {
                activeReelID = reelIDs.first
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .comments(let reel):
                PostCommentsSheet(
                    post: reel,
                    viewerID: model.viewerID,
                    services: services,
                    onAdded: { model.didAddComment(to: reel.id) }
                )
            case .share(let reel):
                ReelShareSheet(reel: reel)
            case .report(let reel):
                PostReportSheet { reason, note in
                    try await model.report(reel, reason: reason, note: note)
                }
            }
        }
    }

    private var reelPager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(model.reels.indices, id: \.self) { index in
                    let reel = model.reels[index]
                    ReelPageView(
                        reel: reel,
                        isPlaying: scenePhase == .active && isTabActive && activeSheet == nil && (activeReelID == nil ? index == 0 : activeReelID == reel.id),
                        isMuted: !unmutedReelIDs.contains(reel.id),
                        onToggleMute: { toggleMute(for: reel) },
                        onLike: { Task { await model.toggleLike(for: reel) } },
                        onComments: { activeSheet = .comments(reel) },
                        onShare: { activeSheet = .share(reel) },
                        onReport: { activeSheet = .report(reel) },
                        onRetry: { Task { await model.load() } }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(reel.id)
                    .onScrollVisibilityChange(threshold: 0.7) { isVisible in
                        if isVisible { activeReelID = reel.id }
                    }
                    .task { await model.loadMoreIfNeeded(currentIndex: index) }
                }

                if model.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical)
                } else if let paginationErrorKey = model.paginationErrorKey {
                    VStack(spacing: 12) {
                        Text(LocalizedStringKey(paginationErrorKey))
                            .foregroundStyle(.white)
                        Button("reels.pagination.retry", systemImage: "arrow.clockwise") {
                            Task { await model.retryLoadMore() }
                        }
                        .buttonStyle(.glass)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .containerRelativeFrame(.vertical)
                    .environment(\.colorScheme, .dark)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $activeReelID)
        .background(.black)
        .accessibilityIdentifier("GlintReelsPager")
    }

    private func toggleMute(for reel: GlintPost) {
        if unmutedReelIDs.contains(reel.id) {
            unmutedReelIDs.remove(reel.id)
        } else {
            unmutedReelIDs.insert(reel.id)
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
