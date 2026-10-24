import SwiftUI

struct PostReportSheet: View {
    let onSubmit: @MainActor (ModerationReason, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ModerationReason = .spam
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var hasError = false
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("report.reason.section") {
                    Picker("report.reason.label", selection: $reason) {
                        ForEach(ModerationReason.allCases, id: \.self) { item in
                            Text(item.titleKey).tag(item)
                        }
                    }
                }

                Section("report.note.section") {
                    TextField("report.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if hasError {
                    Text("report.error.submit")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .navigationTitle("report.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("report.submit") { submit() }
                        .disabled(isSubmitting)
                }
            }
            .alert("report.confirmation.title", isPresented: $didSubmit) {
                Button("common.done") { dismiss() }
            } message: {
                Text("report.confirmation.message")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        hasError = false
        Task {
            defer { isSubmitting = false }
            do {
                try await onSubmit(reason, note.isEmpty ? nil : note)
                didSubmit = true
            } catch {
                hasError = true
            }
        }
    }
}

private extension ModerationReason {
    var titleKey: LocalizedStringKey {
        switch self {
        case .spam: return "report.reason.spam"
        case .abuse: return "report.reason.abuse"
        case .nudity: return "report.reason.nudity"
        case .violence: return "report.reason.violence"
        case .other: return "report.reason.other"
        }
    }
}
