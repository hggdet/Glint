import SwiftUI

@main
@MainActor
struct GlintApp: App {
    @State private var services: GlintServices
    @State private var authModel: AuthViewModel

    init() {
        let services = GlintServices.makeMock()
        _services = State(initialValue: services)
        _authModel = State(initialValue: AuthViewModel(services: services))
    }

    var body: some Scene {
        WindowGroup {
            GlintRootView(model: authModel, services: services)
        }
    }
}
