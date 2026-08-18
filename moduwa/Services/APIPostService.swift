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
    /// 작성자 키. **후기·플랜과 같은 값**을 쓴다 — 따로 만들면 같은 기기가 서비스마다
    /// 다른 사람이 되어 서버가 한 사람으로 묶지 못한다.
    private let deviceId: String

    init(apiKey: String? = nil, session: URLSession = .shared, deviceId: String? = nil) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "MODUWA_API_KEY") as? String)
            ?? Secrets.moduwaAPIKey
            ?? ""
        self.session = session
        self.deviceId = deviceId ?? ReviewAuthorStore.deviceId
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
            // 첫 작성이라 이름을 요구하는 경우만 따로 구분한다 — 호출부가 이름을 받아 다시 시도한다.
            if failure?.error == "missing_authorNm" { throw PostServiceError.nicknameRequired }
            if let message = failure?.message, !message.isEmpty {
                throw PostServiceError.server(message: message)
            }
            throw PostServiceError.unavailable
        }
        return data
    }

    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func url(_ path: String, _ query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        return comps.url!
    }

    // MARK: - 조회

    func fetchPosts(
        mineOnly: Bool, contentId: String?, limit: Int, offset: Int
    ) async throws -> [TravelPost] {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var query: [URLQueryItem] = [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)"),
        ]
        // deviceId 를 실으면 서버가 내 글만 준다 — 전체 목록에는 싣지 않는다.
        if mineOnly { query.append(.init(name: "deviceId", value: deviceId)) }
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
            deviceId: deviceId,
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
        let data = try await data(for: authorized(url("/v1/posts/\(id)", [
            .init(name: "deviceId", value: deviceId),
        ])))
        return try JSONDecoder().decode(PostDTO.self, from: data).post
    }

    // MARK: - 좋아요

    @discardableResult
    func setPostLiked(id: String, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool) {
        guard !apiKey.isEmpty else { throw PostServiceError.unavailable }
        var request = authorized(url("/v1/posts/\(id)/like", [
            .init(name: "deviceId", value: deviceId),
        ]))
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
            deviceId: deviceId,
            // 빈 문자열을 보내면 서버가 기존 닉네임을 덮어쓴다.
            authorNm: (authorNm?.isEmpty ?? true) ? nil : authorNm,
            body: body
        ))
        let data = try await data(for: request)
        return try JSONDecoder().decode(CommentDTO.self, from: data).comment
    }

    private struct CommentBody: Encodable {
        let deviceId: String
        let authorNm: String?
        let body: String
    }

    private struct CommentListResponse: Decodable { let items: [CommentDTO] }

    private struct CommentDTO: Decodable {
        let id: Int
        let author: String?
        let body: String?
        let createdAt: String?

        var comment: PostComment {
            PostComment(
                id: String(id),
                author: author ?? "",
                body: body ?? "",
                createdAt: createdAt.flatMap { try? Date($0, strategy: .iso8601) } ?? .now
            )
        }
    }

    private struct CreateBody: Encodable {
        let deviceId: String
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
        /// ISO8601 UTC
        let createdAt: String?

        var post: TravelPost {
            TravelPost(
                id: id,
                author: author ?? "",
                body: body ?? "",
                imageURLs: (imageURLs ?? []).compactMap(URL.init(string:)),
                places: places ?? [],
                // 앱이 모르는 코드는 버린다 — 서버가 값을 검증하지 않으므로 늘 있을 수 있다.
                accessFeatures: (accessFeatures ?? []).compactMap(AccessibilityFeature.init(rawValue:)),
                likeCount: likeCount ?? 0,
                commentCount: commentCount ?? 0,
                likedByMe: likedByMe ?? false,
                // 목록 정렬은 서버가 하므로 못 읽어도 화면이 어긋나지 않는다.
                createdAt: createdAt.flatMap { try? Date($0, strategy: .iso8601) } ?? .now
            )
        }
    }
}
