import Foundation

/// Deterministic in-process sample content. Asset names are resolved by the app's asset catalog.
public enum MockData {
    public static let currentUser = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000001") ?? UUID(),
        username: "noura.works",
        displayName: "Noura Haddad",
        bio: "Finding little moments of light. \nBaghdad · Design & coffee",
        avatarAssetName: "avatar_noura",
        bannerAssetName: "sample_post_blue_hour",
        followerCount: 2,
        followingCount: 5,
        postCount: 2,
        isPrivate: false,
        isVerified: false,
        avatarShape: .circle,
        createdAt: .now.addingTimeInterval(-86_400 * 220)
    )

    public static let maya = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000002") ?? UUID(),
        username: "maya.frames",
        displayName: "Maya Rahman",
        bio: "Light, landscapes, and everything between.",
        avatarAssetName: "avatar_maya",
        bannerAssetName: "sample_post_rainy_city",
        followerCount: 2,
        followingCount: 2,
        postCount: 3,
        isVerified: true,
        avatarShape: .star,
        createdAt: .now.addingTimeInterval(-86_400 * 600)
    )

    public static let leo = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000003") ?? UUID(),
        username: "leo.cooks",
        displayName: "Leo Chen",
        bio: "Home cooking, no rules.",
        avatarAssetName: "avatar_leo",
        bannerAssetName: "sample_post_lemon_rice",
        followerCount: 1,
        followingCount: 2,
        postCount: 2,
        isVerified: false,
        avatarShape: .roundedSquare,
        createdAt: .now.addingTimeInterval(-86_400 * 430)
    )

    public static let samira = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000004") ?? UUID(),
        username: "samira.sketches",
        displayName: "Samira Ali",
        bio: "Illustrator • Baghdad / Amman",
        avatarAssetName: "avatar_samira",
        bannerAssetName: "sample_post_sketchbook",
        followerCount: 2,
        followingCount: 0,
        postCount: 2,
        isVerified: false,
        avatarShape: .circle,
        createdAt: .now.addingTimeInterval(-86_400 * 310)
    )

    public static let noah = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000005") ?? UUID(),
        username: "noah.outside",
        displayName: "Noah Williams",
        bio: "Weekend trails and long walks.",
        avatarAssetName: "avatar_noah",
        bannerAssetName: "sample_post_mountain_trail",
        followerCount: 1,
        followingCount: 0,
        postCount: 2,
        isVerified: false,
        avatarShape: .hexagon,
        createdAt: .now.addingTimeInterval(-86_400 * 510)
    )

    public static let zara = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000006") ?? UUID(),
        username: "zara.afterhours",
        displayName: "Zara Mahmoud",
        bio: "A little color for the late hours.",
        avatarAssetName: "avatar_zara",
        bannerAssetName: "sample_story_zara",
        followerCount: 1,
        followingCount: 0,
        postCount: 1,
        isVerified: true,
        avatarShape: .circle,
        createdAt: .now.addingTimeInterval(-86_400 * 720)
    )

    public static let privateUser = GlintUser(
        id: UUID(uuidString: "A1000000-0000-4000-8000-000000000007") ?? UUID(),
        username: "layla.private",
        displayName: "Layla Hassan",
        bio: "A quiet corner for close friends.",
        avatarAssetName: "avatar_layla",
        bannerAssetName: "sample_story_maya",
        followerCount: 0,
        followingCount: 0,
        postCount: 1,
        isPrivate: true,
        createdAt: .now.addingTimeInterval(-86_400 * 80)
    )

    public static let users: [GlintUser] = [currentUser, maya, leo, samira, noah, zara, privateUser]

    public static let followingByUserID: [UUID: Set<UUID>] = [
        currentUser.id: [maya.id, leo.id, samira.id, noah.id, zara.id],
        maya.id: [currentUser.id, samira.id],
        leo.id: [maya.id, currentUser.id]
    ]

    public static let followRequests: [FollowRequest] = [
        FollowRequest(
            id: UUID(uuidString: "C3000000-0000-4000-8000-000000000001") ?? UUID(),
            requesterID: currentUser.id,
            targetUserID: privateUser.id,
            status: .pending,
            createdAt: .now.addingTimeInterval(-3_600),
            updatedAt: .now.addingTimeInterval(-3_600)
        ),
        FollowRequest(
            id: UUID(uuidString: "C3000000-0000-4000-8000-000000000002") ?? UUID(),
            requesterID: zara.id,
            targetUserID: currentUser.id,
            status: .pending,
            createdAt: .now.addingTimeInterval(-1_800),
            updatedAt: .now.addingTimeInterval(-1_800)
        )
    ]

    public static let posts: [GlintPost] = [
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000001") ?? UUID(),
            authorID: maya.id,
            caption: "The city looks softer just after the rain.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_rainy_city", accessibilityDescription: "Warm evening light on a rain-washed city street", aspectRatio: 0.82)],
            createdAt: .now.addingTimeInterval(-900),
            likeCount: 248,
            commentCount: 18
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000002") ?? UUID(),
            authorID: leo.id,
            caption: "Crispy edges, soft middle. The good kind of Sunday.",
            media: [PostMedia(kind: .video, assetName: "sample_reel_pasta", accessibilityDescription: "A pan of fresh pasta being tossed", aspectRatio: 0.75, durationSeconds: 19)],
            contentKind: .reel,
            createdAt: .now.addingTimeInterval(-3_600),
            likeCount: 1_032,
            commentCount: 64
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000003") ?? UUID(),
            authorID: samira.id,
            caption: "A sketchbook page from a slow afternoon. What should I draw next?",
            media: [PostMedia(kind: .photo, assetName: "sample_post_sketchbook", accessibilityDescription: "Open sketchbook with colorful drawings", aspectRatio: 1)],
            createdAt: .now.addingTimeInterval(-7_200),
            likeCount: 391,
            commentCount: 31
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000004") ?? UUID(),
            authorID: noah.id,
            caption: "No signal, no rush. Just the trail and the wind.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_mountain_trail", accessibilityDescription: "A quiet mountain trail at sunrise", aspectRatio: 0.8)],
            createdAt: .now.addingTimeInterval(-14_400),
            likeCount: 806,
            commentCount: 42
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000005") ?? UUID(),
            authorID: zara.id,
            caption: "Tiny corner, big energy.",
            media: [PostMedia(kind: .video, assetName: "sample_reel_studio", accessibilityDescription: "Colorful late-night art studio", aspectRatio: 0.75, durationSeconds: 12)],
            contentKind: .reel,
            createdAt: .now.addingTimeInterval(-28_800),
            likeCount: 2_410,
            commentCount: 105
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000006") ?? UUID(),
            authorID: maya.id,
            caption: "A reminder to look up once in a while.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_blue_hour", accessibilityDescription: "Deep blue evening sky between old buildings", aspectRatio: 0.9)],
            createdAt: .now.addingTimeInterval(-86_400),
            likeCount: 512,
            commentCount: 22
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000007") ?? UUID(),
            authorID: samira.id,
            caption: "A small study in warm orange and magenta.",
            media: [],
            createdAt: .now.addingTimeInterval(-129_600),
            likeCount: 167,
            commentCount: 9
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000008") ?? UUID(),
            authorID: leo.id,
            caption: "One-pan lemon rice for a busy night.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_lemon_rice", accessibilityDescription: "Bowl of lemon rice with herbs", aspectRatio: 1)],
            createdAt: .now.addingTimeInterval(-172_800),
            likeCount: 721,
            commentCount: 47
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000009") ?? UUID(),
            authorID: privateUser.id,
            caption: "A small film from a private weekend.",
            media: [PostMedia(kind: .video, assetName: "sample_reel_private_weekend", accessibilityDescription: "A quiet weekend walk filmed on a phone", aspectRatio: 0.75, durationSeconds: 10)],
            contentKind: .reel,
            createdAt: .now.addingTimeInterval(-259_200),
            likeCount: 22,
            commentCount: 2
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000010") ?? UUID(),
            authorID: maya.id,
            caption: "A slow coffee break in a warm corner of the city.",
            media: [PostMedia(kind: .video, assetName: "sample_reel_coffee", accessibilityDescription: "A steaming cup of coffee on a café table", aspectRatio: 0.75, durationSeconds: 3)],
            contentKind: .reel,
            createdAt: .now.addingTimeInterval(-345_600),
            likeCount: 634,
            commentCount: 28
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000011") ?? UUID(),
            authorID: noah.id,
            caption: "Baghdad at the soft edge of dusk.",
            media: [PostMedia(kind: .video, assetName: "sample_reel_baghdad", accessibilityDescription: "A glowing sunset over a quiet Baghdad street", aspectRatio: 0.75, durationSeconds: 3)],
            contentKind: .reel,
            createdAt: .now.addingTimeInterval(-432_000),
            likeCount: 912,
            commentCount: 35
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000012") ?? UUID(),
            authorID: currentUser.id,
            caption: "A little blue-hour pause above Baghdad.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_blue_hour", accessibilityDescription: "Blue evening sky above an old Baghdad street", aspectRatio: 1)],
            createdAt: .now.addingTimeInterval(-21_600),
            likeCount: 96,
            commentCount: 7
        ),
        GlintPost(
            id: UUID(uuidString: "B2000000-0000-4000-8000-000000000013") ?? UUID(),
            authorID: currentUser.id,
            caption: "Small things, saved for later.",
            media: [PostMedia(kind: .photo, assetName: "sample_post_sketchbook", accessibilityDescription: "A notebook open to a bright sketch", aspectRatio: 1)],
            createdAt: .now.addingTimeInterval(-64_800),
            likeCount: 143,
            commentCount: 11
        )
    ]

    /// The home story rail deliberately has exactly four sample stories.
    public static let stories: [GlintStory] = [
        GlintStory(authorID: maya.id, media: PostMedia(kind: .photo, assetName: "sample_story_maya", accessibilityDescription: "Maya's afternoon city walk", aspectRatio: 0.75), createdAt: .now.addingTimeInterval(-1_800)),
        GlintStory(authorID: leo.id, media: PostMedia(kind: .video, assetName: "sample_story_leo", accessibilityDescription: "Leo cooking at home", aspectRatio: 0.75, durationSeconds: 8), createdAt: .now.addingTimeInterval(-3_600)),
        GlintStory(authorID: samira.id, media: PostMedia(kind: .photo, assetName: "sample_story_samira", accessibilityDescription: "Samira's new illustration", aspectRatio: 0.75), createdAt: .now.addingTimeInterval(-7_200)),
        GlintStory(authorID: zara.id, media: PostMedia(kind: .photo, assetName: "sample_story_zara", accessibilityDescription: "Zara's evening studio", aspectRatio: 0.75), createdAt: .now.addingTimeInterval(-10_800))
    ]

    public static let comments: [GlintComment] = [
        GlintComment(postID: posts[0].id, authorID: leo.id, text: "That light is unreal.", createdAt: .now.addingTimeInterval(-600), likeCount: 12),
        GlintComment(postID: posts[0].id, authorID: currentUser.id, text: "Saving this little moment.", createdAt: .now.addingTimeInterval(-420), likeCount: 4),
        GlintComment(postID: posts[1].id, authorID: maya.id, text: "Please share the recipe!", createdAt: .now.addingTimeInterval(-1_800), likeCount: 19),
        GlintComment(postID: posts[2].id, authorID: zara.id, text: "The colors are beautiful.", createdAt: .now.addingTimeInterval(-5_400), likeCount: 7),
        GlintComment(postID: UUID(uuidString: "B2000000-0000-4000-8000-000000000010") ?? UUID(), authorID: leo.id, text: "That looks like the perfect pause.", createdAt: .now.addingTimeInterval(-340_000), likeCount: 8),
        GlintComment(postID: UUID(uuidString: "B2000000-0000-4000-8000-000000000011") ?? UUID(), authorID: maya.id, text: "The evening light is beautiful.", createdAt: .now.addingTimeInterval(-420_000), likeCount: 11)
    ]

    public static let notifications: [GlintNotification] = [
        GlintNotification(id: UUID(uuidString: "C3000000-0000-4000-8000-000000000001") ?? UUID(), recipientID: currentUser.id, event: .like, actorID: maya.id, destination: .post(posts[0].id), createdAt: .now.addingTimeInterval(-300)),
        GlintNotification(id: UUID(uuidString: "C3000000-0000-4000-8000-000000000002") ?? UUID(), recipientID: currentUser.id, event: .comment(text: "That light is unreal."), actorID: leo.id, destination: .post(posts[0].id), createdAt: .now.addingTimeInterval(-1_200)),
        GlintNotification(id: UUID(uuidString: "C3000000-0000-4000-8000-000000000003") ?? UUID(), recipientID: currentUser.id, event: .newFollower, actorID: zara.id, destination: .profile(zara.id), createdAt: .now.addingTimeInterval(-7_200), isRead: true),
        GlintNotification(id: UUID(uuidString: "C3000000-0000-4000-8000-000000000004") ?? UUID(), recipientID: maya.id, event: .like, actorID: currentUser.id, destination: .post(posts[0].id), createdAt: .now.addingTimeInterval(-600))
    ]
}
