import SwiftUI

private enum PostCardSheet: String, Identifiable {
    case comments
    case report
    case share
    var id: String { rawValue }
}

struct GlintPostCard: View {
    let post: GlintPost
    let author: GlintUser
    let viewModel: HomeViewModel
    let services: GlintServices
    let onOpenProfile: (GlintUser) -> Void

    @State private var activeSheet: PostCardSheet?
    @State private var isConfirmingBlock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let media = post.media.first {
                GlintMediaView(media: media)
            }

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            actions
        }
        .padding(16)
        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .comments:
                PostCommentsSheet(
                    post: post,
                    viewerID: viewModel.viewerID,
                    services: services,
                    onAdded: { viewModel.didAddComment(to: post.id) }
                )
            case .report:
                PostReportSheet { reason, note in
                    try await viewModel.reportPost(post, reason: reason, note: note)
                }
            case .share:
                shareSheet
            }
        }
        .confirmationDialog("post.block.confirmation.title", isPresented: $isConfirmingBlock, titleVisibility: .visible) {
            Button("post.block.confirm", role: .destructive) {
                Task { await viewModel.block(authorID: author.id) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("post.block.confirmation.message")
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Button { onOpenProfile(author) } label: {
                HStack(spacing: 10) {
                    GlintAvatarView(user: author, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(author.displayName).font(.subheadline.weight(.semibold))
                            if author.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(GlintPalette.accent)
                                    .accessibilityLabel(Text("profile.verified"))
                            }
                        }
                        Text("@\(author.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(post.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("post.openProfile.hint"))

            Spacer(minLength: 0)

            if author.id != viewModel.viewerID {
                Menu {
                    Button("post.report", systemImage: "flag") { activeSheet = .report }
                    Button("post.block", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                        isConfirmingBlock = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Text("post.more.actions"))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 18) {
            VStack(spacing: 1) {
                GlintActionButton(kind: .like, title: post.isLiked ? "post.unlike" : "post.like", isActive: post.isLiked) {
                    Task { await viewModel.toggleLike(for: post) }
                }
                Text(post.likeCount.formatted())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 1) {
                GlintActionButton(kind: .comment, title: "post.comment") { activeSheet = .comments }
                Text(post.commentCount.formatted())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GlintActionButton(kind: .share, title: "post.share") { activeSheet = .share }
            Spacer()
            GlintActionButton(kind: .save, title: post.isSaved ? "post.saved" : "post.save", isActive: post.isSaved) {
                Task { await viewModel.toggleSave(for: post) }
            }
        }
        .frame(minHeight: 48)
    }

    private var shareSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "paperplane")
                    .font(.system(size: 34))
                    .foregroundStyle(GlintPalette.accent)
                Text("share.post.title").font(.headline)
                ShareLink(item: post.caption.isEmpty ? "Glint" : post.caption) {
                    Label("share.post.button", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 28)
            .navigationTitle("share.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { activeSheet = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
