import SwiftUI

struct SignInView: View {
    @Bindable var model: AuthViewModel

    var body: some View {
        AuthScaffold(title: "auth.signIn.title", subtitle: "auth.signIn.subtitle") {
            VStack(spacing: 14) {
                AuthTextField(
                    title: "auth.email.label",
                    text: $model.email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                AuthTextField(
                    title: "auth.password.label",
                    text: $model.password,
                    contentType: .password,
                    isSecure: true
                )
                Button("auth.forgotPassword.link") { model.showPasswordReset() }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                AuthFeedback(errorKey: model.errorMessageKey, noticeKey: model.noticeMessageKey)
                AuthPrimaryButton(title: "auth.signIn.button", isWorking: model.isWorking) {
                    Task { await model.signIn() }
                }
                Button("auth.backToWelcome.button") { model.showWelcome() }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
