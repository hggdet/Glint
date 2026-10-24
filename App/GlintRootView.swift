import SwiftUI

struct GlintRootView: View {
    @Bindable var model: AuthViewModel
    let services: GlintServices
    @AppStorage("glint.language") private var language = GlintLanguage.system.rawValue
    @AppStorage("glint.appearance") private var appearance = GlintAppearance.system.rawValue

    private var isArabic: Bool {
        if language == GlintLanguage.arabic.rawValue { return true }
        if language == GlintLanguage.english.rawValue { return false }
        return Locale.current.language.languageCode?.identifier == "ar"
    }

    private var activeLocale: Locale {
        if language == GlintLanguage.arabic.rawValue { return Locale(identifier: "ar") }
        if language == GlintLanguage.english.rawValue { return Locale(identifier: "en") }
        return .autoupdatingCurrent
    }

    private var preferredAppearance: ColorScheme? {
        switch GlintAppearance(rawValue: appearance) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        Group {
            switch model.route {
            case .loading:
                GlintSplashView()
            case .welcome:
                WelcomeView(model: model)
            case .signIn:
                SignInView(model: model)
            case .signUp:
                SignUpView(model: model)
            case .passwordReset:
                PasswordResetView(model: model)
            case .profileSetup:
                ProfileSetupView(model: model)
            case .authenticated:
                if let viewerID = model.currentSession?.userID {
                    GlintMainTabView(
                        viewerID: viewerID,
                        services: services,
                        onSignOut: { await model.signOut() },
                        onDeleteAccount: { await model.deleteAccount() }
                    )
                    .id(viewerID)
                } else {
                    GlintSplashView()
                }
            }
        }
        .environment(\.locale, activeLocale)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .preferredColorScheme(preferredAppearance)
        .task {
            guard model.route == .loading else { return }
            await model.restoreSession()
        }
        .task(id: model.currentSession?.userID) {
            language = GlintLanguage.system.rawValue
            appearance = GlintAppearance.system.rawValue
            guard let userID = model.currentSession?.userID else { return }
            guard let preferences = try? await services.settings.loadPreferences(for: userID),
                  model.currentSession?.userID == userID else { return }
            language = preferences.language.rawValue
            appearance = preferences.appearance.rawValue
        }
    }
}
