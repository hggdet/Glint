import Foundation

@MainActor
public protocol PostService: AnyObject {
    func fetchFeed(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost>
    func fetchPosts(by authorID: UUID, for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost>
    func fetchPost(_ postID: UUID, for viewerID: UUID) async throws -> GlintPost
    func fetchExplorePosts(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost>
    func fetchReels(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost>
    func canViewPost(_ postID: UUID, for viewerID: UUID) async throws -> Bool
    func createPost(authorID: UUID, caption: String, media: [PostMedia]) async throws -> GlintPost
    func createReel(authorID: UUID, caption: String, media: [PostMedia]) async throws -> GlintPost
    func toggleLike(postID: UUID, by viewerID: UUID) async throws -> GlintPost
    func toggleSave(postID: UUID, by viewerID: UUID) async throws -> GlintPost
    func fetchComments(postID: UUID, for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintComment>
    func addComment(postID: UUID, authorID: UUID, text: String) async throws -> GlintComment
}
