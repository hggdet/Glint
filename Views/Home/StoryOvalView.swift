import SwiftUI

struct StoryOvalView: View {
    let stories: [GlintStoryFeedItem]
    let authorsByID: [UUID: GlintUser]
    let viewerID: UUID
    let services: GlintServices
    let onSeen: @MainActor (GlintStoryFeedItem) async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedIndex = 0
    @State private var isExpanded = false
    @State private var isViewerPresented = false
    @Namespace private var storyNamespace

    private var visibleStories: [GlintStoryFeedItem] { Array(stories.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.stories.title")
                .font(.headline)
                .padding(.horizontal, 18)

            HStack(spacing: 0) {
                ForEach(visibleStories.indices, id: \.self) { index in
                    storyItem(visibleStories[index], index: index)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 88)
            .padding(.horizontal, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(GlintPalette.surface)
                    .overlay(Capsule(style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > 34, !visibleStories.isEmpty else { return }
                        let direction = value.translation.width < 0 ? 1 : -1
                        selectStory((selectedIndex + direction + visibleStories.count) % visibleStories.count)
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("home.stories.rail"))
        }
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $isViewerPresented) {
            StoryViewerView(
                stories: visibleStories,
                authorsByID: authorsByID,
                viewerID: viewerID,
                services: services,
                selectedIndex: $selectedIndex,
                onSeen: onSeen
            )
        }
    }

    private func storyItem(_ item: GlintStoryFeedItem, index: Int) -> some View {
        let author = authorsByID[item.story.authorID]
        let isSelected = selectedIndex == index && isExpanded
        return Button {
            if isSelected {
                isViewerPresented = true
            } else {
                selectStory(index)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            item.isSeen ? Color.secondary.opacity(0.45) : GlintPalette.secondaryAccent,
                            lineWidth: item.isSeen ? 1 : 2.5
                        )
                        .frame(width: 66, height: 66)
                    if isSelected {
                        GlintMediaView(media: item.story.media, cornerRadius: 18)
                            .frame(width: 56, height: 56)
                            .matchedGeometryEffect(id: item.id, in: storyNamespace)
                            .allowsHitTesting(false)
                    } else if let author {
                        GlintAvatarView(user: author, size: 56)
                            .matchedGeometryEffect(id: item.id, in: storyNamespace)
                    } else {
                        Circle().fill(.quaternary).frame(width: 56, height: 56)
                    }
                }
                .scaleEffect(isSelected && !reduceMotion ? 1.08 : 1)
                Text(author?.username ?? "")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 74)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("home.story.accessibilityLabel"))
        .accessibilityValue(Text(verbatim: author?.username ?? ""))
        .accessibilityHint(Text(isSelected ? "home.story.openViewer.hint" : "home.story.select.hint"))
    }

    private func selectStory(_ index: Int) {
        guard !reduceMotion else {
            selectedIndex = index
            isExpanded = true
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
            selectedIndex = index
            isExpanded = true
        }
    }
}
