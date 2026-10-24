# Glint

Glint is a SwiftUI social-network prototype for iOS 26+, written in Swift 6. The app is mock-first and uses native iOS Liquid Glass controls.

## Generate and build

Install Xcode 26 and XcodeGen, then from this directory run:

```sh
xcodegen generate --spec project.yml
xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The shared `Glint` scheme runs the `GlintTests` XCTest target and references `GlintPlus.storekit` for local StoreKit testing. The GitHub Actions workflow at `.github/workflows/ios-build.yml` runs those tests before building, packages the app as a standard `Payload/Glint.app` unsigned `.ipa`, and checks archive integrity, the iOS arm64 executable, bundle identifier, and absence of signing/provisioning data before upload. It does not sign or publish an app. GitHub Actions has not run until this project is pushed to a GitHub repository.

## Demo sign-in

- Email: `demo@glint.app`
- Password: `glint-demo`

New accounts are stored locally for prototype testing. Do not use a real or reused password.

## Prototype boundaries

Authentication credentials, profiles, posts, stories, comments, notifications, moderation reports, settings, and social graph behavior use local mock services. The StoreKit 2 service and local subscription configuration are scaffolding; `GlintApp` currently injects `MockSubscriptionService`, so the Glint+ purchase UI is explicitly a demo and does not charge money. Terms and Privacy text are drafts. The demo account-deletion action signs out only and does not erase profile or content. There is no production backend, server-side authorization/moderation, push notification, direct messaging, or live streaming.

Before a public release, replace the mock identity and data stores with authenticated server services and access controls, deploy legally reviewed Terms and Privacy policies, and implement complete account-data deletion and report handling.
