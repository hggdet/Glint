import SwiftUI

private enum SettingsDestination: String, Identifiable {
    case editProfile
    case glintPlus
    case terms
    case privacy
    var id: String { rawValue }
}

@MainActor
struct SettingsView: View {
    @Bindable var model: SettingsViewModel
    @Bindable var profileModel: ProfileViewModel
    let onSignOut: @MainActor () async -> Bool
    let onDeleteAccount: @MainActor () async -> Bool
    let onPrivacyChanged: @MainActor () async -> Void
    let onNotificationPreferencesChanged: @MainActor () async -> Void

    @AppStorage("glint.language") private var appLanguage = GlintLanguage.system.rawValue
    @AppStorage("glint.appearance") private var appAppearance = GlintAppearance.system.rawValue
    @State private var destination: SettingsDestination?
    @State private var isBlockedExpanded = false
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var actionErrorKey: String?

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    GlintLoadingState(lineCount: 5)
                case .failed:
                    GlintErrorState(
                        title: "settings.error.title",
                        message: LocalizedStringKey(model.errorKey ?? "settings.error.load"),
                        retryTitle: "auth.retry.button",
                        retry: { Task { await load() } }
                    )
                case .ready:
                    settingsContent
                }
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.isSavingPreferences { ProgressView() }
                }
            }
            .sheet(item: $destination) { item in
                switch item {
                case .editProfile:
                    if let user = model.user {
                        EditProfileView(user: user, model: profileModel) {
                            Task {
                                await model.load()
                                syncRootPreferences()
                                await onPrivacyChanged()
                            }
                        }
                    }
                case .glintPlus:
                    GlintPlusSheet(model: profileModel)
                case .terms:
                    LegalSettingsDocumentView(isTerms: true)
                case .privacy:
                    LegalSettingsDocumentView(isTerms: false)
                }
            }
            .confirmationDialog("settings.signOut.confirm.title", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
                Button("settings.signOut", role: .destructive) { Task { await signOut() } }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.signOut.confirm.message")
            }
            .confirmationDialog("settings.delete.confirm.title", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("settings.delete.confirm.action", role: .destructive) { Task { await deleteAccount() } }
                    .disabled(isDeletingAccount)
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.delete.demoNotice")
            }
            .task { await load() }
        }
    }

    private var settingsContent: some View {
        List {
            if let message = actionErrorKey ?? model.errorKey {
                Text(LocalizedStringKey(message))
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.clear)
            }
            if let notice = model.noticeKey {
                Text(LocalizedStringKey(notice))
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .listRowBackground(Color.clear)
            }

            Section("settings.account.section") {
                if let user = model.user {
                    HStack(spacing: 12) {
                        GlintAvatarView(user: displayedUser(user), size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName).font(.headline)
                            Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("settings.account.demo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Button { destination = .editProfile } label: {
                        Label("settings.account.edit", systemImage: "person.crop.circle")
                    }
                    Button { destination = .glintPlus } label: {
                        Label("settings.managePlus", systemImage: "sparkles")
                    }
                }
            }

            Section("settings.privacy.section") {
                Toggle("settings.privacy.privateAccount", isOn: Binding(
                    get: { model.user?.isPrivate ?? false },
                    set: { value in
                        Task {
                            await model.setPrivateAccount(value)
                            if model.user?.isPrivate == value { await onPrivacyChanged() }
                        }
                    }
                ))
                .disabled(model.isUpdatingPrivacy)
                Text("settings.privacy.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                DisclosureGroup("settings.blocked.title", isExpanded: $isBlockedExpanded) {
                    if model.blockedUsers.isEmpty {
                        Text("settings.blocked.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.blockedUsers) { blocked in
                            HStack(spacing: 10) {
                                GlintAvatarView(user: displayedUser(blocked), size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(blocked.displayName).font(.subheadline.weight(.medium))
                                    Text("@\(blocked.username)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("settings.blocked.unblock") {
                                    Task {
                                        await model.unblock(blocked)
                                        await onPrivacyChanged()
                                    }
                                }
                                .buttonStyle(.glass)
                                .disabled(model.unblockingUserIDs.contains(blocked.id))
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .onChange(of: isBlockedExpanded) { _, expanded in
                    if expanded { Task { await model.refreshBlockedUsers() } }
                }
            }

            Section("settings.notifications.section") {
                Toggle("settings.notifications.likes", isOn: notificationBinding(.likes))
                    .disabled(model.isSavingPreferences)
                Toggle("settings.notifications.comments", isOn: notificationBinding(.comments))
                    .disabled(model.isSavingPreferences)
                Toggle("settings.notifications.followers", isOn: notificationBinding(.newFollowers))
                    .disabled(model.isSavingPreferences)
                Text("settings.notifications.inAppOnly")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("settings.preferences.section") {
                Picker("settings.language", selection: Binding(
                    get: { model.preferences.language },
                    set: { value in Task { await saveLanguage(value) } }
                )) {
                    Text("settings.language.system").tag(GlintLanguage.system)
                    Text("settings.language.english").tag(GlintLanguage.english)
                    Text("settings.language.arabic").tag(GlintLanguage.arabic)
                }
                .disabled(model.isSavingPreferences)
                Picker("settings.appearance", selection: Binding(
                    get: { model.preferences.appearance },
                    set: { value in Task { await saveAppearance(value) } }
                )) {
                    Text("settings.appearance.system").tag(GlintAppearance.system)
                    Text("settings.appearance.light").tag(GlintAppearance.light)
                    Text("settings.appearance.dark").tag(GlintAppearance.dark)
                }
                .disabled(model.isSavingPreferences)
            }

            Section("settings.information.section") {
                LabeledContent("settings.version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("settings.about", value: "Glint")
                Text("settings.help.message")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("auth.terms.link") { destination = .terms }
                Button("auth.privacy.link") { destination = .privacy }
            }

            Section {
                Button {
                    isConfirmingSignOut = true
                } label: {
                    if isSigningOut { ProgressView() }
                    else { Label("settings.signOut", systemImage: "rectangle.portrait.and.arrow.right") }
                }
                .disabled(isSigningOut || isDeletingAccount)

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    if isDeletingAccount { ProgressView() }
                    else { Label("settings.delete.title", systemImage: "person.crop.circle.badge.xmark") }
                }
                .disabled(isDeletingAccount || isSigningOut)
                Text("settings.delete.demoNotice")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func load() async {
        await model.load()
        guard model.state == .ready else { return }
        syncRootPreferences()
        await profileModel.refresh()
    }

    private func syncRootPreferences() {
        appLanguage = model.preferences.language.rawValue
        appAppearance = model.preferences.appearance.rawValue
    }

    private func notificationBinding(_ kind: NotificationPreferenceKind) -> Binding<Bool> {
        Binding(
            get: {
                switch kind {
                case .likes: return model.preferences.notificationPreferences.likes
                case .comments: return model.preferences.notificationPreferences.comments
                case .newFollowers: return model.preferences.notificationPreferences.newFollowers
                }
            },
            set: { value in
                Task {
                    await model.setNotificationPreference(kind, isEnabled: value)
                    await onNotificationPreferencesChanged()
                }
            }
        )
    }

    private func saveLanguage(_ language: GlintLanguage) async {
        if await model.setLanguage(language) { appLanguage = language.rawValue }
    }

    private func saveAppearance(_ appearance: GlintAppearance) async {
        if await model.setAppearance(appearance) { appAppearance = appearance.rawValue }
    }

    private func signOut() async {
        isSigningOut = true
        actionErrorKey = nil
        defer { isSigningOut = false }
        if !(await onSignOut()) { actionErrorKey = "settings.error.signOut" }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        actionErrorKey = nil
        defer { isDeletingAccount = false }
        if !(await onDeleteAccount()) { actionErrorKey = "settings.error.delete" }
    }

    private func displayedUser(_ source: GlintUser) -> GlintUser {
        guard source.id == model.viewerID else { return source }
        guard profileModel.tier == .glintPlus else {
            var copy = source
            copy.avatarShape = .circle
            return copy
        }
        return source
    }
}

@MainActor
private struct LegalSettingsDocumentView: View {
    let isTerms: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey(isTerms ? "legal.terms.draft" : "legal.privacy.draft"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(GlintPalette.background.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(isTerms ? "auth.terms.link" : "auth.privacy.link"))
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
