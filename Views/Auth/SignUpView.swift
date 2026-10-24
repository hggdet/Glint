import SwiftUI

private enum LegalDocument: String, Identifiable {
    case terms
    case privacy
    var id: String { rawValue }

    var title: LocalizedStringKey {
        self == .terms ? "auth.terms.link" : "auth.privacy.link"
    }

    var bodyText: LocalizedStringKey {
        self == .terms ? "legal.terms.draft" : "legal.privacy.draft"
    }
}

struct SignUpView: View {
    @Bindable var model: AuthViewModel
    @State private var legalDocument: LegalDocument?

    private var consentTitle: LocalizedStringKey {
        model.acceptedTerms ? "auth.signup.consentAccepted" : "auth.signup.consent"
    }

    var body: some View {
        AuthScaffold(title: "auth.signUp.title", subtitle: "auth.signUp.subtitle") {
            VStack(spacing: 14) {
                Text("auth.signup.demoWarning")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                AuthTextField(
                    title: "auth.email.label",
                    text: $model.email,
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                )
                AuthTextField(
                    title: "auth.password.label",
                    text: $model.password,
                    contentType: .newPassword,
                    isSecure: true
                )
                AuthTextField(
                    title: "auth.confirmPassword.label",
                    text: $model.confirmPassword,
                    contentType: .newPassword,
                    isSecure: true
                )
                Button {
                    model.acceptedTerms.toggle()
                } label: {
                    Label(
                        consentTitle,
                        systemImage: model.acceptedTerms ? "checkmark.circle.fill" : "circle"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.acceptedTerms ? .isSelected : [])
                HStack(spacing: 14) {
                    Button("auth.terms.link") { legalDocument = .terms }
                    Button("auth.privacy.link") { legalDocument = .privacy }
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                AuthFeedback(errorKey: model.errorMessageKey, noticeKey: model.noticeMessageKey)
                AuthPrimaryButton(title: "auth.signUp.button", isWorking: model.isWorking) {
                    Task { await model.signUp() }
                }
                Button("auth.backToWelcome.button") { model.showWelcome() }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.bodyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                        .accessibilityIdentifier("legalCloseButton")
                }
            }
        }
    }
}
