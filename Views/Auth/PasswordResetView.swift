import SwiftUI

struct PasswordResetView: View {
    @Bindable var model: AuthViewModel

    var body: some View {
        AuthScaffold(title: "auth.reset.title", subtitle: "auth.reset.subtitle") {
            VStack(spacing: 14) {
                AuthTextField(
                    title: "auth.email.label",
                    text: $model.email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                AuthFeedback(errorKey: model.errorMessageKey, noticeKey: model.noticeMessageKey)
                if model.resetRequestSent {
                    Label("auth.reset.complete", systemImage: "envelope.badge")
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    AuthPrimaryButton(title: "auth.reset.button", isWorking: model.isWorking) {
                        Task { await model.requestPasswordReset() }
                    }
                }
                Button("auth.backToSignIn.button") { model.showSignIn() }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
