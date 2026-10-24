import SwiftUI

struct WelcomeView: View {
    @Bindable var model: AuthViewModel

    var body: some View {
        AuthScaffold(title: "auth.welcome.title", subtitle: "auth.welcome.subtitle") {
            VStack(spacing: 14) {
                AuthPrimaryButton(title: "auth.signIn.button", isWorking: false) {
                    model.showSignIn()
                }
                AuthPrimaryButton(title: "auth.signUp.button", isWorking: false) {
                    model.showSignUp()
                }
                AuthFeedback(errorKey: model.errorMessageKey, noticeKey: model.noticeMessageKey)
                if model.errorMessageKey != nil {
                    Button("auth.retry.button") {
                        Task { await model.restoreSession() }
                    }
                    .buttonStyle(.glass)
                }
                Text("auth.demo.credentials")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("auth.welcome.legalNote")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .accessibilityElement(children: .contain)
        }
    }
}
