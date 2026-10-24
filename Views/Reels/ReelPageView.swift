import SwiftUI

@MainActor
struct ReelPageView: View {
    let reel: GlintPost
    let isPlaying: Bool
    let isMuted: Bool
    let onToggleMute: () -> Void
    let onLike: () -> Void
    let onComments: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onRetry: () -> Void

    private var videoMedia: PostMedia? { reel.media.first(where: { $0.kind == .video }) }
    private var videoURL: URL? {
        guard let videoMedia else { return nil }
        return GlintMediaView(media: videoMedia).videoURL
    }

    var body: some View {
        ZStack {
            Color.black
            if let videoMedia, let videoURL {
                ReelVideoPlayerView(
                    url: videoURL,
                    isPlaying: isPlaying,
                    isMuted: isMuted,
                    accessibilityLabel: GlintMediaView(media: videoMedia).accessibilityText,
                    onToggleMute: onToggleMute,
                    onLongPressReport: onReport
                )
            } else {
                Color.black
                    .overlay {
                        GlintErrorState(
                            title: "reels.error.video.title",
                            message: "reels.error.video.message",
                            retryTitle: "auth.retry.button",
                            retry: onRetry
                        )
                        .environment(\.colorScheme, .dark)
                    }
            }

            HStack(alignment: .bottom) {
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 44)
        }
        .contentShape(Rectangle())
        .background(.black)
        .accessibilityIdentifier("reel.page.\(reel.id.uuidString)")
    }

    private var actions: some View {
        VStack(spacing: 20) {
            VStack(spacing: 3) {
                GlintActionButton(
                    kind: .like,
                    title: reel.isLiked ? "post.unlike" : "post.like",
                    isActive: reel.isLiked,
                    action: onLike
                )
                Text(reel.likeCount.formatted())
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 3) {
                GlintActionButton(kind: .comment, title: "post.comment", action: onComments)
                Text(reel.commentCount.formatted())
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            GlintActionButton(kind: .share, title: "post.share", action: onShare)
        }
        .padding(.bottom, 72)
        .environment(\.colorScheme, .dark)
    }
}
