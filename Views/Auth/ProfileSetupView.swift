import SwiftUI

private enum AvatarPreset: String, CaseIterable, Identifiable {
    case noura = "avatar_noura"
    case maya = "avatar_maya"
    case samira = "avatar_samira"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .noura: return "sparkles"
        case .maya: return "camera.macro"
        case .samira: return "paintpalette.fill"
        }
    }

    var tint: Color {
        switch self {
        case .noura: return GlintPalette.accent
        case .maya: return .orange
        case .samira: return .purple
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .noura: return "auth.avatar.optionOne"
        case .maya: return "auth.avatar.optionTwo"
        case .samira: return "auth.avatar.optionThree"
        }
    }
}

struct ProfileSetupView: View {
    @Bindable var model: AuthViewModel

    private var usernameBinding: Binding<String> {
        Binding(
            get: { model.profileUsername },
            set: { model.updateProfileUsername($0) }
        )
    }

    var body: some View {
        AuthScaffold(title: "auth.profile.title", subtitle: "auth.profile.subtitle") {
            VStack(alignment: .leading, spacing: 16) {
                Text("auth.profile.avatarPrompt")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 12) {
                    ForEach(AvatarPreset.allCases) { preset in
                        let selected = model.profileAvatarAssetName == preset.rawValue
                        Button {
                            model.profileAvatarAssetName = preset.rawValue
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: preset.symbol)
                                    .font(.title2)
                                    .foregroundStyle(preset.tint)
                                    .frame(width: 58, height: 58)
                                    .glassEffect(.regular, in: Circle())
                                    .overlay {
                                        Circle().stroke(selected ? GlintPalette.accent : .clear, lineWidth: 2)
                                    }
                                Text(preset.title).font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.title)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }

                AuthTextField(title: "auth.profile.username", text: usernameBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("auth.profile.username")
                usernameStatus
                AuthTextField(title: "auth.profile.displayName", text: $model.profileDisplayName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("auth.profile.displayName")
                AuthFeedback(errorKey: model.errorMessageKey, noticeKey: model.noticeMessageKey)
                AuthPrimaryButton(title: "auth.profile.finish", isWorking: model.isWorking) {
                    Task { await model.completeProfile() }
                }
            }
        }
    }

    @ViewBuilder
    private var usernameStatus: some View {
        switch model.usernameAvailability {
        case .checking:
            Label("auth.profile.usernameChecking", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .available:
            Label("auth.profile.usernameAvailable", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .taken:
            Label("auth.profile.usernameTaken", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .invalid:
            Label("auth.profile.usernameInvalid", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .idle:
            Text("auth.profile.usernameRule")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
