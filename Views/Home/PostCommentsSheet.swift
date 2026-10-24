import SwiftUI

struct PostCommentsSheet: View {
    let post: GlintPost
    let viewerID: UUID
    let services: GlintServices
    let onAdded: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [GlintComment] = []
    @State private var authors: [UUID: GlintUser] = [:]
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var hasError = false
    @State private var hasSendError = false
    @State private var reportingCommentID: UUID?
    @State private var isReportPresented = false
    @FocusState private var inputFocused: Bool

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 0) {
                    if isLoading {
                        GlintLoadingState(lineCount: 3)
                    } else if hasError && comments.isEmpty {
                        GlintErrorState(
                            title: "comments.error.title",
                            message: "comments.error.message",
                            retryTitle: "auth.retry.button",
                            retry: { Task { await loadComments() } }
                        )
                    } else if comments.isEmpty {
                        GlintEmptyState(
                            systemImage: "text.bubble",
                            title: "comments.empty.title",
                            message: "comments.empty.message"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(comments) { comment in
                                    commentRow(comment)
                                }
                            }
                            .padding(16)
                        }
                    }

                    if hasError && !comments.isEmpty {
                        Text("comments.error.message")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                    if hasSendError {
                        Text("comments.send.error")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }
                    composer
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .navigationTitle("comments.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        inputFocused = false
                        dismiss()
                    }
                }
            }
            .task { await loadComments() }
            .sheet(isPresented: $isReportPresented) {
                if let reportingCommentID {
                    PostReportSheet { reason, note in
                        let report = ModerationReport(
                            reporterID: viewerID,
                            target: .comment(reportingCommentID),
                            reason: reason,
                            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 }
                        )
                        try await services.moderation.submitReport(report)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("comments.placeholder", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await sendComment() } }
            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(GlintPalette.accent)
            }
            .disabled(trimmedDraft.isEmpty || isSending)
            .accessibilityLabel(Text("comments.send"))
        }
        .padding(14)
        .background(GlintPalette.surface)
    }

    @ViewBuilder
    private func commentRow(_ comment: GlintComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let author = authors[comment.authorID] {
                GlintAvatarView(user: author, size: 36)
            } else {
                Circle().fill(.quaternary).frame(width: 36, height: 36)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(authors[comment.authorID]?.username ?? "")
                    .font(.subheadline.weight(.semibold))
                Text(comment.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            if comment.authorID != viewerID {
                Menu {
                    Button("report.comment.action", systemImage: "flag") {
                        reportingCommentID = comment.id
                        isReportPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Text("report.comment.action"))
            }
        }
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func loadComments() async {
        isLoading = true
        hasError = false
        defer { isLoading = false }
        do {
            let page = try await services.posts.fetchComments(postID: post.id, for: viewerID, page: 0, pageSize: 50)
            comments = page.items
            for authorID in Set(page.items.map(\.authorID)) {
                let source = try await services.users.fetchUser(id: authorID, viewedBy: viewerID)
                authors[authorID] = try await userForDisplay(source)
            }
        } catch {
            hasError = true
        }
    }

    @MainActor
    private func sendComment() async {
        guard !trimmedDraft.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await services.posts.addComment(postID: post.id, authorID: viewerID, text: trimmedDraft)
            comments.append(comment)
            if let source = try? await services.users.fetchUser(id: viewerID, viewedBy: viewerID),
               let user = try? await userForDisplay(source) {
                authors[viewerID] = user
            }
            draft = ""
            hasError = false
            hasSendError = false
            onAdded()
        } catch {
            hasSendError = true
        }
    }

    @MainActor
    private func userForDisplay(_ source: GlintUser) async throws -> GlintUser {
        var user = source
        guard source.id == viewerID || services.subscriptions is MockSubscriptionService else { return user }
        let tier = try await services.subscriptions.currentTier(for: source.id)
        if tier != .glintPlus { user.avatarShape = .circle }
        return user
    }
}
