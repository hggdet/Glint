import Foundation

/// Dependency container used by the app entry point and view models.
/// Production can inject Supabase-backed services without changing the UI layer.
@MainActor
public final class GlintServices {
    public let auth: any AuthService
    public let posts: any PostService
    public let users: any UserService
    public let stories: any StoryService
    public let notifications: any NotificationService
    public let moderation: any ModerationService
    public let settings: any SettingsService
    public let subscriptions: any SubscriptionService

    public init(
        auth: any AuthService,
        posts: any PostService,
        users: any UserService,
        stories: any StoryService,
        notifications: any NotificationService,
        moderation: any ModerationService,
        settings: any SettingsService,
        subscriptions: any SubscriptionService
    ) {
        self.auth = auth
        self.posts = posts
        self.users = users
        self.stories = stories
        self.notifications = notifications
        self.moderation = moderation
        self.settings = settings
        self.subscriptions = subscriptions
    }

    public static func makeMock() -> GlintServices {
        let subscriptions = MockSubscriptionService()
        let settings = MockSettingsService()
        let notificationStore = MockNotificationStore()
        let users = MockUserService(
            profileStore: UserDefaultsMockUserProfileStore(),
            subscriptionService: subscriptions,
            socialGraphStore: UserDefaultsMockSocialGraphStore(),
            notificationSink: notificationStore
        )
        let moderation = MockModerationService()
        let posts = MockPostService(
            userService: users,
            moderationService: moderation,
            notificationSink: notificationStore
        )
        return GlintServices(
            auth: MockAuthService(
                sessionStore: KeychainAuthSessionStore(),
                consentStore: UserDefaultsLegalConsentStore(),
                credentialStore: UserDefaultsMockCredentialStore()
            ),
            posts: posts,
            users: users,
            stories: MockStoryService(userService: users, moderationService: moderation),
            notifications: MockNotificationService(
                userService: users,
                postService: posts,
                settingsService: settings,
                store: notificationStore
            ),
            moderation: moderation,
            settings: settings,
            subscriptions: subscriptions
        )
    }
}
