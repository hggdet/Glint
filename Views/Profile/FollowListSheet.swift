import SwiftUI

@MainActor
struct FollowListSheet: View {
    enum Kind: Equatable {
        case followers
        case following
    }

    let userID: UUID
    let viewerID: UUID
    let kind: Kind
    let services: GlintServices

    @Environment(\.dismiss) private var dismiss
    @State private var users: [GlintUser] = []
    @State private var selectedUser: GlintUser?
    @State private var isLoading = true
    @State private var errorKey: String?

    private var title: LocalizedStringKey {
        kind == .followers ? "profile.followers" : "profile.following"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    GlintLoadingState(lineCount: 5)
                } else if let errorKey {
                    GlintErrorState(
                        title: "profile.list.error.title",
                        message: LocalizedStringKey(errorKey),
                        retryTitle: "auth.retry.button",
                        retry: { Task { await load() } }
                    )
                } else if users.isEmpty {
                    GlintEmptyState(systemImage: "person.2", title: "profile.list.empty.title", message: "profile.list.empty.message")
                } else {
                    List(users) { user in
                        Button { selectedUser = user } label: {
                            HStack(spacing: 12) {
                                GlintAvatarView(user: user, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.displayName).font(.subheadline.weight(.semibold))
                                    Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(GlintPalette.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(item: $selectedUser) { user in
                OtherProfileView(profileID: user.id, viewerID: viewerID, services: services) {
                    Task { await load() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorKey = nil
        defer { isLoading = false }
        do {
            switch kind {
            case .followers: users = try await services.users.followers(of: userID, viewedBy: viewerID)
            case .following: users = try await services.users.following(for: userID, viewedBy: viewerID)
            }
            if services.subscriptions is MockSubscriptionService {
                for index in users.indices {
                    let tier = try await services.subscriptions.currentTier(for: users[index].id)
                    if tier != .glintPlus { users[index].avatarShape = .circle }
                }
            }
        } catch {
            errorKey = "profile.list.error.generic"
        }
    }
}
