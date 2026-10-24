import SwiftUI

@MainActor
struct SearchView: View {
    let viewerID: UUID
    let services: GlintServices
    @Environment(\.dismiss) private var dismiss
    @State private var model: SearchViewModel
    @State private var selectedUser: GlintUser?
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
        _model = State(initialValue: SearchViewModel(viewerID: viewerID, services: services))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchField
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        recentSection
                        exploreSection
                    } else {
                        peopleSection
                        if model.peopleState == .ready, model.people.isEmpty,
                           searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                            GlintEmptyState(systemImage: "person.crop.circle.badge.questionmark", title: "search.people.empty.title", message: "search.people.empty.message")
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("search.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(item: $selectedUser) { user in
                OtherProfileView(profileID: user.id, viewerID: viewerID, services: services) {
                    Task { await model.refreshAfterPrivacyChange() }
                }
            }
            .onChange(of: searchText) { _, value in model.updateQuery(value) }
            .task { await model.loadExplore() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("search.field.placeholder", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { model.recordSearch(searchText) }
                .accessibilityIdentifier("search.people.field")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    model.updateQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("search.clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var recentSection: some View {
        if !model.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("search.recent.title").font(.headline)
                    Spacer()
                    Button("search.recent.clear") { model.clearRecentSearches() }
                        .font(.caption.weight(.semibold))
                }
                ForEach(model.recentSearches, id: \.self) { term in
                    Button {
                        searchText = term
                        model.updateQuery(term)
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(GlintPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("search.people.title").font(.headline).padding(.horizontal, 18)
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                Text("search.people.minimum")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
            } else {
                switch model.peopleState {
                case .loading:
                    GlintLoadingState(lineCount: 3).padding(.horizontal, 16)
                case .failed:
                    GlintErrorState(
                        title: "search.error.title",
                        message: LocalizedStringKey(model.peopleErrorKey ?? "search.error.people"),
                        retryTitle: "auth.retry.button",
                        retry: { model.updateQuery(searchText) }
                    )
                    .padding(.horizontal, 16)
                case .ready:
                    ForEach(model.people) { user in
                        Button {
                            model.recordSearch(searchText)
                            selectedUser = user
                        } label: {
                            HStack(spacing: 12) {
                                GlintAvatarView(user: user, size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Text(user.displayName).font(.subheadline.weight(.semibold))
                                        if user.isVerified { Image(systemName: "checkmark.seal.fill").foregroundStyle(GlintPalette.accent) }
                                    }
                                    Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if user.isPrivate { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("search.explore.title")
                .font(.headline)
                .padding(.horizontal, 18)
            switch model.exploreState {
            case .loading:
                GlintLoadingState(lineCount: 4).padding(.horizontal, 16)
            case .failed:
                GlintErrorState(
                    title: "search.error.title",
                    message: LocalizedStringKey(model.exploreErrorKey ?? "search.error.explore"),
                    retryTitle: "auth.retry.button",
                    retry: { Task { await model.loadExplore() } }
                )
                .padding(.horizontal, 16)
            case .ready:
                if model.explorePosts.isEmpty {
                    GlintEmptyState(systemImage: "safari", title: "search.explore.empty.title", message: "search.explore.empty.message")
                        .padding(.horizontal, 16)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                        ForEach(model.explorePosts) { post in
                            Button {
                                selectedUser = model.authorsByID[post.authorID]
                            } label: {
                                exploreTile(post)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: post.caption.isEmpty ? "Explore post" : post.caption))
                        }
                    }
                    .padding(.horizontal, 3)
                }
            }
        }
    }

    @ViewBuilder
    private func exploreTile(_ post: GlintPost) -> some View {
        if let media = post.media.first, media.kind == .photo {
            GlintMediaView(media: media, cornerRadius: 0)
        } else {
            Rectangle()
                .fill(LinearGradient(colors: [GlintPalette.accent.opacity(0.7), GlintPalette.secondaryAccent.opacity(0.6), GlintPalette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: post.containsVideo ? "play.fill" : "text.alignleft").foregroundStyle(.white))
        }
    }
}
