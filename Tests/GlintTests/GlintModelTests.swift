import XCTest
@testable import Glint

final class GlintModelTests: XCTestCase {
    func testLegacyPostDefaultsToPostAndClampsNegativeCounters() throws {
        let postID = UUID()
        let authorID = UUID()
        let json = """
        {
          "id": "\(postID.uuidString)",
          "authorID": "\(authorID.uuidString)",
          "likeCount": -3,
          "commentCount": -2,
          "shareCount": -1
        }
        """

        let post = try JSONDecoder().decode(GlintPost.self, from: Data(json.utf8))

        XCTAssertEqual(post.id, postID)
        XCTAssertEqual(post.authorID, authorID)
        XCTAssertEqual(post.contentKind, .post)
        XCTAssertEqual(post.likeCount, 0)
        XCTAssertEqual(post.commentCount, 0)
        XCTAssertEqual(post.shareCount, 0)
    }

    func testReelKindSurvivesCodableRoundTrip() throws {
        let post = GlintPost(
            authorID: UUID(),
            caption: "A short video",
            media: [PostMedia(kind: .video, assetName: "sample-video")],
            contentKind: .reel,
            createdAt: Date(timeIntervalSince1970: 1_750_000_000)
        )

        let encoded = try JSONEncoder().encode(post)
        let decoded = try JSONDecoder().decode(GlintPost.self, from: encoded)

        XCTAssertEqual(decoded, post)
        XCTAssertEqual(decoded.contentKind, .reel)
        XCTAssertTrue(decoded.containsVideo)
    }

    func testLegacyProfileDefaultsMissingAvatarShapeToCircle() throws {
        let userID = UUID()
        let json = """
        {
          "id": "\(userID.uuidString)",
          "username": "legacy_user",
          "displayName": "Legacy User"
        }
        """

        let user = try JSONDecoder().decode(GlintUser.self, from: Data(json.utf8))

        XCTAssertEqual(user.id, userID)
        XCTAssertEqual(user.avatarShape, .circle)
        XCTAssertEqual(user.bio, "")
        XCTAssertEqual(user.followerCount, 0)
    }

    func testAccountPreferencesCodableRoundTrip() throws {
        let preferences = AppPreferences(
            language: .arabic,
            appearance: .dark,
            notificationPreferences: NotificationPreferences(
                likes: false,
                comments: true,
                newFollowers: false
            )
        )

        let encoded = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: encoded)

        XCTAssertEqual(decoded, preferences)
    }
}
