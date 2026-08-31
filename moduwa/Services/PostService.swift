import SwiftUI

/// 게시글 작성·조회 실패 사유 중 **사용자에게 그대로 보여 줄 수 있는** 것들.
/// (URLError 등 시스템 오류는 감싸지 않고 호출부가 일반 문구로 처리한다 — 다른 서비스와 같은 규칙)
enum PostServiceError: LocalizedError {
    case unavailable
    case server(message: String)
    /// 이 기기의 첫 작성이라 서버가 표시 이름을 요구함. 호출부가 이름을 받아 다시 시도한다.
    case nicknameRequired
    /// 401 `login_required` — 작성·좋아요·"내 글"·"좋아요한 글"은 로그인 필수다(백엔드 030).
    case loginRequired
    /// 401 `session_expired` — 토큰이 낡았다. 앱은 로그아웃 상태로 돌아간다.
    case sessionExpired
    /// 404 — 이미 지워졌거나 내 것이 아니다. **댓글 수정·삭제에서만 따로 가른다**:
    /// 서버가 삭제를 멱등으로 두지 않아(두 번 지우면 404) "이미 없어졌다"를 오류가 아니라
    /// 목록을 맞추는 신호로 다뤄야 한다.
    case notFound

    var errorDescription: String? {
        switch self {
        case .unavailable: "지금은 게시할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .server(let message): message
        case .nicknameRequired: "게시글에 표시될 이름을 입력해 주세요."
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .notFound: "이미 지워졌어요."
        }
    }
}

/// 게시글에 붙은 장소. 글이 쓰인 시점의 이름을 그대로 들고 있다 —
/// 원본 POI 가 사라져도 옛 글이 빈 줄을 보여 주지 않는다.
struct PostPlace: Identifiable, Hashable, Sendable, Codable {
    var contentID: String
    var name: String
    var region: String?

    var id: String { contentID }
}

/// 여행 게시글.
struct TravelPost: Identifiable, Hashable, Sendable {
    let id: String
    var author: String
    /// 작성자 프로필 사진(서버 `authorInfo.avatarUrl`, 042). 없으면 이니셜 원을 그린다.
    var authorAvatarURL: URL? = nil
    var body: String
    var imageURLs: [URL]
    var places: [PostPlace]
    /// 작성자가 고른 무장애 정보. 앱이 모르는 코드는 뱃지를 그리지 않는다 —
    /// 서버가 값을 검증하지 않으므로(앱이 아이콘을 늘리면 서버 배포 없이 따라가야 한다).
    var accessFeatures: [AccessibilityFeature]
    var likeCount: Int
    var commentCount: Int
    /// 이 기기가 좋아요를 눌렀는지. 서버가 보는 사람 기준으로 준다.
    var likedByMe: Bool
    var createdAt: Date
    /// 보는 사람이 쓴 글인지(서버 `isMine`). 수정·삭제 메뉴를 띄울 근거다.
    /// `likedByMe` 와 같은 성질의 파생 값이고 비로그인은 false 다.
    var isMine: Bool = false
}

/// 게시글 댓글.
struct PostComment: Identifiable, Hashable, Sendable {
    let id: String
    var author: String
    /// 작성자 프로필 사진(`authorInfo.avatarUrl`). 없으면 이니셜 원.
    var authorAvatarURL: URL? = nil
    var body: String
    var createdAt: Date
    /// 보는 사람이 쓴 댓글인지(서버 `isMine`). 수정·삭제 메뉴를 띄울 근거다.
    var isMine: Bool = false
}

/// 게시글 데이터 소스 (`/v1/posts`).
///
/// 작성자와 "보는 사람"은 모두 **로그인한 계정**이다(백엔드 030). 세션 토큰은 구현체가
/// 요청마다 붙이므로 호출부는 아무것도 넘기지 않는다.
///
/// 목록 읽기는 **비로그인도 된다**(둘러보기). 그 경우 `likedByMe` 는 전부 false 다.
protocol PostService: Sendable {
    /// 최근 글부터. 무엇도 좁히지 않으면 전체 목록이다.
    ///
    /// 로그인했으면 구현체가 세션 토큰을 실어 **보는 사람**을 알린다 — 그러지 않으면
    /// 하트가 이미 누른 글에서도 빈 상태로 그려진다.
    /// - Parameters:
    ///   - mineOnly: 내가 쓴 글만. **로그인 필수**(비로그인이면 `.loginRequired`).
    ///   - likedOnly: 내가 좋아요한 글만 — **내가 누른 순서**로 온다
    ///     (글이 쓰인 시각이 아니다). 저장 탭의 "좋아요한 게시물"이 쓴다. **로그인 필수**.
    ///   - contentId: 그 장소를 **붙인** 글만 (장소 후기 화면의 "여행 게시글" 탭).
    func fetchPosts(
        mineOnly: Bool, likedOnly: Bool, contentId: String?, limit: Int, offset: Int
    ) async throws -> [TravelPost]

    /// 게시글 작성.
    /// - Parameter authorNm: 사용자가 **직접 정한** 표시 이름만 넘긴다. 정하지 않았으면 nil —
    ///   서버가 기존 닉네임을 재사용하고, 정말 첫 작성이면 `.nicknameRequired` 를 던진다.
    ///   ⚠️ 지어낸 기본 이름을 넣지 말 것: 서버가 받은 이름으로 이 기기의 닉네임을 갱신한다.
    /// 사진 업로드는 여기 없다 — `FeedService.uploadReviewImages` 를 그대로 쓴다.
    /// 서버가 파일명을 내용의 sha256 으로 정해 경로 접두사가 뜻을 갖지 않으므로,
    /// 멀티파트 조립 코드를 한 벌 더 두는 것보다 재사용이 낫다.
    @discardableResult
    func createPost(
        body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature], authorNm: String?
    ) async throws -> TravelPost

    /// 게시글 하나. 상세 화면이 좋아요·댓글 수까지 최신값으로 받는다.
    func fetchPost(id: String) async throws -> TravelPost

    /// 게시글 수정(`PATCH /v1/posts/:postId`, 서버 2026-08-31).
    ///
    /// **온 키만 갱신되고 배열은 통째로 교체된다** — 사진·장소를 부분 병합하지 않으므로
    /// 남길 것까지 함께 실어야 한다(빈 배열은 "다 지운다"는 뜻이다).
    /// `authorNm` 은 보내지 않는다(서버가 받지 않는다) — 프로필 편집이 생긴 뒤로 글을 고친다고
    /// 닉네임이 따라 바뀌면 안 된다.
    /// - Returns: 갱신된 글. 목록 카드와 상세를 이 값으로 갱신한다.
    @discardableResult
    func updatePost(
        id: String, body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature]
    ) async throws -> TravelPost

    /// 게시글 삭제. **내 글만** 지워진다 — 남의 글이면 서버가 `404` 를 준다(존재 여부를 알려 주지
    /// 않는 편이 낫다는 서버 판단). 성공은 204 라 돌려줄 값이 없다.
    ///
    /// 수정은 아직 없다 — 서버에 `PATCH /v1/posts/:postId` 가 없다
    /// (`docs/BACKEND_REQUEST_2026-08-31.md` 요청 1).
    func deletePost(id: String) async throws

    /// 좋아요 켜기/끄기. 멱등이다.
    /// - Returns: 서버가 센 좋아요 수와 내가 누른 상태.
    @discardableResult
    func setPostLiked(id: String, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool)

    /// 댓글. 오래된 순(대화 순서).
    func fetchPostComments(id: String, limit: Int, offset: Int) async throws -> [PostComment]

    /// 댓글 작성. **닉네임이 필요하다** — 사람에게 귀속되는 글이다(좋아요와 다르다).
    @discardableResult
    func createPostComment(id: String, body: String, authorNm: String?) async throws -> PostComment

    /// 댓글 수정(`PATCH …/comments/:commentId`, 서버 2026-08-31). 본인 것만, 나머지는 404.
    /// ⚠️ **빈 본문은 400 이다** — 지우려면 삭제를 쓴다(수정이 두 번째 삭제 경로가 되지 않게
    /// 서버가 막았다). 응답은 갱신된 댓글 전체이고 `isMine` 도 들어 있어 재조회가 필요 없다.
    @discardableResult
    func updatePostComment(postId: String, commentId: String, body: String) async throws -> PostComment

    /// 댓글 삭제. 하드 삭제다.
    /// ⚠️ **멱등이 아니다** — 두 번 지우면 404(`.notFound`). 그건 "누가 이미 지웠다"는 뜻이라
    /// 오류로 보여 주지 않고 목록을 맞춘다.
    func deletePostComment(postId: String, commentId: String) async throws
}

extension EnvironmentValues {
    @Entry var postService: any PostService = MockPostService()
}

/// 프리뷰 전용 — 실제로 저장하지 않는다.
struct MockPostService: PostService {
    func fetchPosts(
        mineOnly: Bool, likedOnly: Bool, contentId: String?, limit: Int, offset: Int
    ) async throws -> [TravelPost] { [] }

    @discardableResult
    func createPost(
        body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature], authorNm: String?
    ) async throws -> TravelPost {
        TravelPost(id: UUID().uuidString, author: authorNm ?? "여행자", body: body,
                   imageURLs: imageURLs, places: places, accessFeatures: accessFeatures,
                   likeCount: 0, commentCount: 0, likedByMe: false, createdAt: .now)
    }

    func fetchPost(id: String) async throws -> TravelPost { throw PostServiceError.unavailable }

    @discardableResult
    func updatePost(
        id: String, body: String, imageURLs: [URL], places: [PostPlace],
        accessFeatures: [AccessibilityFeature]
    ) async throws -> TravelPost {
        TravelPost(id: id, author: "여행자", body: body, imageURLs: imageURLs, places: places,
                   accessFeatures: accessFeatures, likeCount: 0, commentCount: 0,
                   likedByMe: false, createdAt: .now)
    }

    func deletePost(id: String) async throws {}

    @discardableResult
    func setPostLiked(id: String, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool) {
        (likeCount: liked ? 1 : 0, likedByMe: liked)
    }

    func fetchPostComments(id: String, limit: Int, offset: Int) async throws -> [PostComment] { [] }

    @discardableResult
    func createPostComment(id: String, body: String, authorNm: String?) async throws -> PostComment {
        PostComment(id: UUID().uuidString, author: authorNm ?? "여행자", body: body, createdAt: .now)
    }

    @discardableResult
    func updatePostComment(postId: String, commentId: String, body: String) async throws -> PostComment {
        PostComment(id: commentId, author: "여행자", body: body, createdAt: .now, isMine: true)
    }

    func deletePostComment(postId: String, commentId: String) async throws {}
}
