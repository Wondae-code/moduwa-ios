import Foundation

/// 라이브 API 연동 PostService — `GET /v1/posts`, `POST /v1/posts`.
///
/// 번들 폴백이 없다 — 게시글은 사용자가 쓴 데이터라 대체할 원본이 없고, 목 데이터로 메우면
/// 쓴 적 없는 글이 자기 목록에 있는 것처럼 보인다(`APIPlanService` 와 같은 규칙).
struct APIPostService: PostService {
    private let baseURL = URL(
        string: ProcessInfo.processInfo.environment["MODUWA_API_BASE_URL"]
            ?? "https://moduwa-backend-production.up.railway.app"
    )!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? Secrets.moduwaAPIKey
            ?? ""
        self.session = session
    }

    // MARK: - HTTP

    private struct ListResponse: Decodable { let items: [PostDTO] }

    private struct ErrorResponse: Decodable {
        let error: String?
        let message: String?
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PostServiceError.unavailable }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            // 쓰기와 "내 글·좋아요한 글" 필터는 로그인 필수다. 401 의 두 뜻을 갈라 준다.
            switch ModuwaAPI.authFailure(status: http.statusCode, code: failure?.error) {
            case .loginRequired: throw PostServiceError.loginRequired
            case .expired: throw PostServiceError.sessionExpired
            case nil: break
            }
            // 첫 작성이라 이름을 요구하는 경우만 따로 구분한다 — 호출부가 이름을 받아 다시 시도한다.
            if failure?.error == "missing_authorNm" { throw PostServiceError.nicknameRequired }
            // 404 는 "없다"가 아니라 **"이미 없어졌다"** 로 다뤄야 하는 자리가 있다(댓글 삭제는
            //  멱등이 아니라 두 번 지우면 404 다). 서버 문구를 그대로 보여 주는 대신 따로 가른다.
            //  ⚠️ 형식이 틀린 id 도 404 로 온다(서버 2026-08-31: 예전엔 500 이었다).
            if http.statusCode == 404 { throw PostServiceError.notFound }
            if let message = failure?.message, !message.isEmpty {
                throw PostServiceError.server(message: message)
            }
            throw PostServiceError.unavailable
        }
        return data
    }

    /// API 키 + **세션 토큰**. 목록에서도 세션이 "보는 사람"이라 빠지면 하트가
    /// 이미 누른 글에서도 빈 상태로 그려진다.
    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        ModuwaAPI.attachSession(to: &request)
        return request
    }

    private func url(_ path: String, _ query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        return comps.url!
    }

    // MARK: - 조회

    func fetchPosts(
        mineOnly: Bool, likedOnly: Bool, contentId: String?, limit: Int, offset: Int
    ) async throws -> [TravelPost] {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        // ⚠️ **보는 사람은 세션이 정한다.** 목록 자체는 공개라 비로그인도 받을 수 있고,
        //  그 경우 `likedByMe` 는 전부 false 로 온다. 목록을 좁히는 것은 mine·liked 이며
        //  그 둘은 로그인 필수다(비로그인이면 서버가 401 `login_required`).
        //  예전에는 deviceId 가 "보는 사람"과 "내 글만"을 겸해서, 하트를 그리려고 값을 실으면
        //  목록이 내 글로 좁혀졌다. 두 뜻을 가른 것이 지금 구조다.
        var query: [URLQueryItem] = [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        if mineOnly { query.append(.init(name: "mine", value: "true")) }
        if likedOnly { query.append(.init(name: "liked", value: "true")) }
        if let contentId, !contentId.isEmpty {
            query.append(.init(name: "contentId", value: contentId))
        }
        let data = try await data(for: authorized(url("/v1/posts", query)))
        return try JSONDecoder().decode(ListResponse.self, from: data).items.map(\.post)
    }

    // MARK: - 작성

    @discardableResult
    func createPost(
        body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature], authorNm: String?
    ) async throws -> TravelPost {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateBody(
            // 빈 문자열을 보내면 서버가 기존 닉네임을 덮어쓴다 — 정하지 않았으면 아예 빼야 한다.
            authorNm: (authorNm?.isEmpty ?? true) ? nil : authorNm,
            body: body,
            imageURLs: imageURLs.map(\.absoluteString),
            places: places,
            accessFeatures: accessFeatures.map(\.rawValue)
        ))
        let data = try await data(for: request)
        return try JSONDecoder().decode(PostDTO.self, from: data).post
    }

    func fetchPost(id: String) async throws -> TravelPost {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        let data = try await data(for: authorized(url("/v1/posts/\(id)")))
        return try JSONDecoder().decode(PostDTO.self, from: data).post
    }

    /// `PATCH /v1/posts/:postId` — 본인 글만, 없거나 남의 글이면 `404`(삭제와 같은 규칙).
    ///
    /// 네 키를 **항상 모두** 보낸다. 서버는 온 키만 갱신하므로 빼도 되지만, 편집 화면이
    /// 넷 다 고칠 수 있어서 "안 바꿨다"와 "지웠다"를 앱이 구분해 봐야 이득이 없다 —
    /// 화면의 현재 상태가 곧 저장할 상태다.
    @discardableResult
    func updatePost(
        id: String, body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature]
    ) async throws -> TravelPost {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UpdateBody(
            body: body,
            imageURLs: imageURLs.map(\.absoluteString),
            places: places,
            accessFeatures: accessFeatures.map(\.rawValue)
        ))
        let data = try await data(for: request)
        return try JSONDecoder().decode(PostDTO.self, from: data).post
    }

    private struct UpdateBody: Encodable {
        let body: String
        let imageURLs: [String]
        let places: [PostPlace]
        let accessFeatures: [String]
    }

    /// `DELETE /v1/posts/:postId` — 서버가 세션의 계정으로 범위를 좁혀 지운다(본인 글만).
    /// 204 라 본문이 없고, 남의 글·없는 글은 `404` 로 온다 — 이때 서버 문구가 그대로 사용자에게
    /// 보인다("게시글을 찾을 수 없습니다.").
    func deletePost(id: String) async throws {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(id)"))
        request.httpMethod = "DELETE"
        _ = try await data(for: request)
    }

    // MARK: - 좋아요

    @discardableResult
    func setPostLiked(id: String, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool) {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(id)/like"))
        request.httpMethod = liked ? "PUT" : "DELETE"
        let data = try await data(for: request)
        let result = try JSONDecoder().decode(LikeDTO.self, from: data)
        return (likeCount: result.likeCount, likedByMe: result.likedByMe)
    }

    private struct LikeDTO: Decodable {
        let likeCount: Int
        let likedByMe: Bool
    }

    // MARK: - 댓글

    func fetchPostComments(id: String, limit: Int, offset: Int) async throws -> [PostComment] {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        let data = try await data(for: authorized(url("/v1/posts/\(id)/comments", [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ])))
        return try JSONDecoder().decode(CommentListResponse.self, from: data).items.map(\.comment)
    }

    @discardableResult
    func createPostComment(id: String, body: String, authorNm: String?) async throws -> PostComment {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(id)/comments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CommentBody(
            // 빈 문자열을 보내면 서버가 기존 닉네임을 덮어쓴다.
            authorNm: (authorNm?.isEmpty ?? true) ? nil : authorNm,
            body: body
        ))
        let data = try await data(for: request)
        return try JSONDecoder().decode(CommentDTO.self, from: data).comment
    }

    /// `PATCH /v1/posts/:postId/comments/:commentId` — 본인 것만, 나머지는 전부 404.
    @discardableResult
    func updatePostComment(postId: String, commentId: String, body: String) async throws -> PostComment {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(postId)/comments/\(commentId)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 닉네임은 보내지 않는다 — 고치는 것은 내용뿐이다(서버도 body 만 받는다).
        request.httpBody = try JSONSerialization.data(withJSONObject: ["body": body])
        let data = try await data(for: request)
        return try JSONDecoder().decode(CommentDTO.self, from: data).comment
    }

    /// `DELETE /v1/posts/:postId/comments/:commentId` — 204. 두 번 지우면 404 다(멱등 아님).
    func deletePostComment(postId: String, commentId: String) async throws {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(postId)/comments/\(commentId)"))
        request.httpMethod = "DELETE"
        _ = try await data(for: request)
    }

    private struct CommentBody: Encodable {
        let authorNm: String?
        let body: String
    }

    private struct CommentListResponse: Decodable { let items: [CommentDTO] }

    /// 작성자 프로필 — 서버가 **기존 `author` 문자열을 그대로 두고 나란히** 덧붙인 객체다
    /// (후기의 `authorInfo` 와 같은 모양이라 서버가 파서 공유를 의도했다). 구 서버에는 없어 옵셔널.
    private struct AuthorInfoDTO: Decodable {
        let nickname: String?
        let avatarUrl: String?
        /// 차단이 가리킬 식별자(서버 048). 구 응답에는 없어 옵셔널이다.
        let uuid: String?
    }

    private struct CommentDTO: Decodable {
        let id: Int
        let author: String?
        let body: String?
        let createdAt: String?
        let authorInfo: AuthorInfoDTO?
        /// 키가 없던 시절의 응답을 견디려고 옵셔널이다(서버는 coalesce 로 null 을 막았다).
        let isMine: Bool?

        var comment: PostComment {
            PostComment(
                id: String(id),
                author: author ?? "",
                authorAvatarURL: URL(imageAddress: authorInfo?.avatarUrl),
                body: body ?? "",
                createdAt: createdAt.flatMap { try? Date($0, strategy: .iso8601) } ?? .now,
                isMine: isMine ?? false,
                authorUUID: authorInfo?.uuid
            )
        }
    }

    private struct CreateBody: Encodable {
        let authorNm: String?
        let body: String
        let imageURLs: [String]
        let places: [PostPlace]
        let accessFeatures: [String]
    }

    // MARK: - DTO

    private struct PostDTO: Decodable {
        let id: String
        let author: String?
        let body: String?
        let imageURLs: [String]?
        let places: [PostPlace]?
        let accessFeatures: [String]?
        let likeCount: Int?
        let commentCount: Int?
        let likedByMe: Bool?
        /// 보는 사람이 쓴 글인지(서버 2026-08-31). 옵셔널로 받는 이유는 서버가 null 을 주기
        /// 때문이 아니라(coalesce 로 막아 두었다) **키가 없던 시절의 응답을 견디기 위해서**다.
        let isMine: Bool?
        /// ISO8601 UTC
        let createdAt: String?
        let authorInfo: AuthorInfoDTO?

        var post: TravelPost {
            TravelPost(
                id: id,
                author: author ?? "",
                authorAvatarURL: URL(imageAddress: authorInfo?.avatarUrl),
                body: body ?? "",
                imageURLs: (imageURLs ?? []).compactMap(URL.init(string:)),
                places: places ?? [],
                // 앱이 모르는 코드는 버린다 — 서버가 값을 검증하지 않으므로 늘 있을 수 있다.
                accessFeatures: (accessFeatures ?? []).compactMap(AccessibilityFeature.init(rawValue:)),
                likeCount: likeCount ?? 0,
                commentCount: commentCount ?? 0,
                likedByMe: likedByMe ?? false,
                // 목록 정렬은 서버가 하므로 못 읽어도 화면이 어긋나지 않는다.
                createdAt: createdAt.flatMap { try? Date($0, strategy: .iso8601) } ?? .now,
                // 없으면 false — 메뉴가 안 보이는 쪽으로 실패한다(남의 글에 보이는 것보다 낫다).
                isMine: isMine ?? false,
                authorUUID: authorInfo?.uuid
            )
        }
    }
}
