import SwiftUI

@MainActor
struct GlintMainTabView: View {
    let viewerID: UUID
    let services: GlintServices
    let onSignOut: @MainActor () async -> Bool
    let onDeleteAccount: @MainActor () async -> Bool

    @State private var selectedTab = 0
    @State private var homeModel: HomeViewModel
    @State private var reelsModel: ReelsViewModel
    @State private var profileModel: ProfileViewModel
    @State private var settingsModel: SettingsViewModel

    init(
        viewerID: UUID,
        services: GlintServices,
        onSignOut: @escaping @MainActor () async -> Bool,
        onDeleteAccount: @escaping @MainActor () async -> Bool
    ) {
        self.viewerID = viewerID
        self.services = services
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        _homeModel = State(initialValue: HomeViewModel(viewerID: viewerID, services: services))
        _reelsModel = State(initialValue: ReelsViewModel(viewerID: viewerID, services: services))
        _profileModel = State(initialValue: ProfileViewModel(viewerID: viewerID, services: services))
        _settingsModel = State(initialValue: SettingsViewModel(viewerID: viewerID, services: services))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: homeModel, services: services)
                .tabItem { Label("tab.home", systemImage: "house.fill") }
                .tag(0)

            ReelsView(model: reelsModel, services: services, isTabActive: selectedTab == 1)
                .tabItem { Label("tab.reels", systemImage: "play.rectangle.fill") }
                .tag(1)

            OwnProfileView(model: profileModel, isTabActive: selectedTab == 2) {
                Task { await homeModel.load() }
            }
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
                .tag(2)

            SettingsView(
                model: settingsModel,
                profileModel: profileModel,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount,
                onPrivacyChanged: { await homeModel.load() },
                onNotificationPreferencesChanged: {
                    if let count = try? await services.notifications.unreadCount(for: viewerID) {
                        homeModel.updateUnreadNotificationCount(count)
                    }
                }
            )
                .tabItem { Label("tab.settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(GlintPalette.accent)
        .task { await homeModel.load() }
    }
}
