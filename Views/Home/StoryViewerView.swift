import SwiftUI

struct StoryViewerView: View {
    let stories: [GlintStoryFeedItem]
    let authorsByID: [UUID: GlintUser]
    let viewerID: UUID
    let services: GlintServices
    @Binding var selectedIndex: Int
    let onSeen: @MainActor (GlintStoryFeedItem) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReportPresented = false
    @State private var reportStoryID: UUID?

    private var currentItem: GlintStoryFeedItem? {
        guard stories.indices.contains(selectedIndex) else { return nil }
        return stories[selectedIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let currentItem {
                VStack(spacing: 14) {
                    progressRail
                    header(for: currentItem)
                    Spacer(minLength: 0)
                    storyMedia(currentItem)
                        .padding(.horizontal, 10)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { advance(by: 1) }
                        .accessibilityHint(Text("home.story.advance.hint"))
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            } else {
                Text("home.stories.empty")
                    .foregroundStyle(.white)
            }
        }
        .statusBarHidden()
        .task(id: selectedIndex) {
            if let item = currentItem { await onSeen(item) }
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > 40 else { return }
                    advance(by: value.translation.width < 0 ? 1 : -1)
                }
        )
        .sheet(isPresented: $isReportPresented) {
            if let reportStoryID {
                PostReportSheet { reason, note in
                    let report = ModerationReport(
                        reporterID: viewerID,
                        target: .story(reportStoryID),
                        reason: reason,
                        note: note?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 }
                    )
                    try await services.moderation.submitReport(report)
                }
            }
        }
    }

    private var progressRail: some View {
        HStack(spacing: 4) {
            ForEach(stories.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= selectedIndex ? .white : .white.opacity(0.32))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 14)
        .accessibilityHidden(true)
    }

    private func header(for item: GlintStoryFeedItem) -> some View {
        HStack(spacing: 10) {
            if let author = authorsByID[item.story.authorID] {
                GlintAvatarView(user: author, size: 38)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(authorsByID[item.story.authorID]?.displayName ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(item.story.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            if let story = currentItem, story.story.authorID != viewerID {
                Menu {
                    Button("report.story.action", systemImage: "flag") {
                        reportStoryID = story.story.id
                        isReportPresented = true
                    }
                    Button("common.close", systemImage: "xmark") { dismiss() }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Text("home.story.actions"))
            } else {
                Button("common.close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel(Text("common.close"))
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func storyMedia(_ item: GlintStoryFeedItem) -> some View {
        if item.story.media.kind == .video,
           let url = GlintMediaView(media: item.story.media).videoURL {
            StoryVideoView(
                url: url,
                accessibilityLabel: GlintMediaView(media: item.story.media).accessibilityText,
                onAdvance: { advance(by: 1) }
            )
                .id(item.id)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            GlintMediaView(media: item.story.media, cornerRadius: 18)
        }
    }

    private func advance(by step: Int) {
        guard !stories.isEmpty else { dismiss(); return }
        let next = selectedIndex + step
        if stories.indices.contains(next) {
            if reduceMotion {
                selectedIndex = next
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedIndex = next
                }
            }
        } else {
            dismiss()
        }
    }
}
