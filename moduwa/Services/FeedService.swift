import SwiftUI

/// 피드 페이지 크기 상수
enum FeedPage {
    static let placeSize = 6
    static let reviewSize = 5
    /// 홈 "여행자 리뷰" 섹션에 함께 싣는 게시글의 페이지 크기.
    /// 후기보다 큰 이유: 게시글은 아직 수가 적어 한 번에 넉넉히 받아도 부담이 없다.
    static let postSize = 10
    /// 장소 상세 후기 목록 페이지 크기 — 시안(352:31)이 한 화면에 한두 건만 보여 주고
    /// "후기 더보기"(352:33)로 이어 받는 구조라 홈 피드보다 작게 잡는다.
    static let placeReviewSize = 3
    /// 장소 후기 전용 화면(`PlaceReviewsView`)의 페이지 크기.
    /// 프리뷰(3건)와 달리 목록이 본문이라 한 번에 더 받는다.
    static let placeReviewListSize = 10
    /// 리뷰 상세 댓글 페이지 크기.
    ///
    /// 후기 목록보다 크게 잡는다 — 댓글은 **오래된 순**이라 새 댓글이 마지막 페이지에 붙는다.
    /// 페이지가 작으면 방금 쓴 댓글을 보려고 "더보기"를 여러 번 눌러야 한다.
    static let reviewCommentSize = 20
}

/// 후기 등록·조회에서 사용자에게 그대로 보여 줄 수 있는 실패 사유.
/// (URLError 등 시스템 오류는 이 타입으로 감싸지 않고 호출부에서 일반 문구로 처리한다)
enum FeedServiceError: LocalizedError {
    /// 이 데이터 소스로는 쓰기를 지원하지 않음 (번들 폴백 등)
    case writeUnsupported
    /// 서버가 준 한국어 오류 메시지 (`{error, message}`)
    case server(message: String)
    /// 사진 업로드 실패 (네트워크/디코딩 등 서버 문구가 없는 경우)
    case imageUploadFailed
    /// 이 리뷰의 댓글을 다룰 수 없음 — 서버 리뷰 id가 없는 번들/목 데이터의 리뷰다.
    case commentsUnavailable
    /// 이 기기의 첫 작성이라 서버가 표시 이름을 요구함. 호출부가 이름을 정해 다시 시도한다.
    case nicknameRequired
    /// 401 `login_required` — 아직 로그인하지 않았다. 후기·댓글·저장은 로그인 필수다(백엔드 030).
    /// 호출부는 로그인 시트를 띄운다.
    case loginRequired
    /// 401 `session_expired` — 토큰이 낡았다. 이미 지워졌고 앱은 로그아웃 상태로 돌아간다.
    case sessionExpired
    /// 404 — 이미 지워졌거나 내 것이 아니다. 댓글 삭제가 멱등이 아니라(두 번 지우면 404)
    /// "이미 없어졌다"를 오류가 아니라 목록을 맞추는 신호로 다뤄야 해서 따로 가른다.
    case notFound

    var errorDescription: String? {
        switch self {
        case .writeUnsupported: "지금은 후기를 등록할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .server(let message): message
        case .imageUploadFailed: "사진을 올리지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        case .nicknameRequired: "댓글에 표시될 이름을 입력해 주세요."
        case .commentsUnavailable: "이 후기의 댓글은 지금 볼 수 없어요."
        case .loginRequired: "로그인이 필요해요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .notFound: "이미 지워졌어요."
        }
    }
}

/// 홈 피드 데이터 소스.
/// 서버 연동 시 이 프로토콜을 구현한 APIFeedService를 만들고,
/// moduwaApp에서 `.environment(\.feedService, APIFeedService())` 한 줄로 교체한다.
protocol FeedService: Sendable {
    /// 홈 "추천 여행지" 그리드. `page`는 0부터, `FeedPage.placeSize`보다 적게 오면 마지막 페이지다.
    ///
    /// - Parameter accessFeatures: 로그인한 사람이 고른 무장애 요소. **모두 만족하는 곳만** 온다
    ///   (AND). 빈 배열이면 무장애 정보가 있는 곳 전체다.
    ///   ⚠️ 서버가 모르는 축(고령자 친화)은 구현체가 걸러 낸다 — 그 축으로는 좁혀지지 않는다.
    ///   ⚠️ 청각 지원은 원본 데이터가 전국 107곳뿐이라 목록이 빠르게 바닥난다. 그게 사실이므로
    ///   다른 곳으로 채우지 않는다.
    func fetchRecommendedPlaces(
        category: PlaceCategory, page: Int, accessFeatures: [AccessibilityFeature]
    ) async throws -> [Place]
    /// `page`는 0부터. `FeedPage.reviewSize`보다 적게 반환되면 마지막 페이지다.
    func fetchReviews(sort: ReviewSort, page: Int) async throws -> [TravelReview]
    /// 저장한 장소 목록 (`GET /v1/saved-places`) — 최근 저장한 순.
    /// 평점은 후기 집계라 `Place.rating`에 실려 온다(무장애 목록에는 그 값이 없다).
    /// - Parameter accessFeatures: 카드의 뱃지·한 줄 설명을 **고른 축 기준**으로 고르는 데 쓴다.
    ///   목록을 좁히지는 않는다(저장한 것은 조건과 무관하게 다 보여야 한다) — 홈과 다른 점이다.
    func fetchSavedPlaces(accessFeatures: [AccessibilityFeature]) async throws -> [Place]

    /// 장소 저장/해제 (`PUT`/`DELETE /v1/saved-places/:contentId`). 둘 다 멱등이다.
    func setPlaceSaved(contentId: String, _ saved: Bool) async throws

    /// 후기 좋아요 토글 (`PUT`/`DELETE /v1/reviews/:reviewId/like`). 멱등이다.
    /// - Parameter reviewId: `TravelReview.serverId`. 없는 후기(번들·목)는 이 API 를 쓸 수 없다.
    /// - Returns: 서버가 센 좋아요 수와 내가 누른 상태.
    @discardableResult
    func setReviewLiked(reviewId: Int, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool)

    /// 장소 상세 (무장애 속성 포함)
    func fetchPlaceDetail(contentId: String) async throws -> PlaceDetail

    // MARK: - 장소 상세 하단 3섹션

    /// 장소별 후기 집계 (평점·후기 수)
    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary
    /// 장소별 후기 목록. `page`는 0부터, `pageSize`보다 적게 오면 마지막 페이지다.
    ///
    /// 프로토콜 요구사항에는 기본 인자를 쓸 수 없어(Swift 제약) 호출부가 전부 명시한다.
    /// - `hasImage`: true면 사진이 있는 후기만 (`"사진/영상 후기만 보기"`)
    /// - `visitorTag`: "같은 조건인 사람의 후기만"(서버 051). **`visitor` 종류 코드만 받는다** —
    ///   장소 평가 코드를 넣으면 서버가 0건을 준다.
    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool,
        visitorTag: String?, page: Int, pageSize: Int
    ) async throws -> [TravelReview]
    /// 함께 가볼만한 곳 (같은 권역의 무장애 장소)
    func fetchRelatedPlaces(contentId: String, limit: Int) async throws -> [RelatedPlace]
    /// 후기 태그 사전 (`GET /v1/review-tags`). 작성 칩·뱃지·집계 막대가 모두 이 목록을 기준으로 그린다.
    func fetchReviewTags() async throws -> [ReviewTag]
    /// 후기 사진 업로드 (`POST /v1/reviews/images`). 반환 URL을 그대로 `ReviewDraft.imageURLs`에 싣는다.
    /// - Parameter images: **이미 다운스케일·JPEG 인코딩을 마친** 바이트 (`ReviewPhotoEncoder` 참고)
    func uploadReviewImages(_ images: [Data]) async throws -> [URL]
    /// 후기 등록. 성공하면 반환값 없이 끝나고, 실패는 throw로만 알린다.
    func submitReview(_ draft: ReviewDraft) async throws

    // MARK: - 리뷰 댓글

    /// 리뷰 댓글 목록 (`GET /v1/reviews/:reviewId/comments`).
    /// `page`는 0부터. 반환된 `items`는 **오래된 순**이다.
    /// - Parameter reviewId: `TravelReview.serverId`. 없는 id는 서버가 404를 준다.
    func fetchReviewComments(reviewId: Int, page: Int, pageSize: Int) async throws -> ReviewCommentPage
    /// 댓글 작성 (`POST /v1/reviews/:reviewId/comments`).
    ///
    /// 반환값이 없는 이유: 성공 뒤 화면은 목록을 다시 받는다. 서버가 같은 트랜잭션에서
    /// `reviews.comment_count`를 올리므로 재조회해야 `total`과 목록 순서가 함께 맞는다.
    /// 응답 한 건만 로컬 배열에 붙이면 개수를 따로 추측해야 하고 재조회 시 중복된다.
    /// - Parameter authorNm: 사용자가 **직접 정한** 표시 이름만 넘긴다. 정하지 않았으면 `nil`.
    ///   ⚠️ 지어낸 기본 이름을 넣지 말 것 — 서버는 받은 이름으로 이 기기의 닉네임을 갱신하므로,
    ///   기기에 저장된 값이 비었다는 이유로 기본 이름을 보내면 **서버에 있던 실제 닉네임을 덮어쓴다**
    ///   (실제로 프로덕션에서 한 사용자의 닉네임이 이렇게 지워진 적이 있다).
    ///   `nil` 을 보내면 서버가 계정에 있는 닉네임을 그대로 쓴다.
    ///
    /// **로그인 필수**다 — 비로그인이면 `.loginRequired` 를 던진다(`deviceId` 는 더 이상
    /// 신원이 아니라서 예전처럼 기기 키로 대신할 수 없다).
    func submitReviewComment(reviewId: Int, body: String, authorNm: String?) async throws

    /// 댓글 수정 (`PATCH /v1/reviews/:reviewId/comments/:commentId`, 서버 2026-08-31).
    /// 본인 것만, 나머지는 404. ⚠️ **빈 본문은 400 이다** — 지우려면 삭제를 쓴다.
    ///
    /// 작성과 달리 반환값이 있다: 개수가 바뀌지 않으므로 그 줄만 갈아끼우면 되고,
    /// 목록을 다시 받으면 사용자가 보고 있던 스크롤 위치를 잃는다.
    @discardableResult
    func updateReviewComment(reviewId: Int, commentId: Int, body: String) async throws -> ReviewComment

    /// 댓글 삭제 (`DELETE /v1/reviews/:reviewId/comments/:commentId`). 하드 삭제다.
    ///
    /// 서버가 같은 트랜잭션에서 `reviews.comment_count` 를 내린다(`greatest(…, 0)` 로 감쌌다) —
    /// 앱은 목록을 다시 받아 `total` 까지 함께 맞춘다(작성과 같은 판단).
    /// ⚠️ **멱등이 아니다** — 두 번 지우면 404(`.notFound`).
    func deleteReviewComment(reviewId: Int, commentId: Int) async throws

    // 신고는 여기 없다 — 대상이 후기만이 아니게 되어 `ReportService` 로 옮겼다
    //  (`POST /v1/reports` 하나가 게시글·후기·양쪽 댓글을 받는다).
}

/// 장소 상세 하단 3섹션용 API는 라이브 서버에만 있다. 오프라인 폴백(`BundledFeedService`)에는
/// 대응 데이터가 없으므로 "이 소스에는 없음"을 뜻하는 기본 구현을 한 곳에 둔다
/// (구현체 3개에 같은 빈 함수를 복사하면 어느 게 진짜 미구현인지 구분되지 않는다).
extension FeedService {
    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary {
        .empty(contentId: contentId)
    }

    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool,
        visitorTag: String?, page: Int, pageSize: Int
    ) async throws -> [TravelReview] {
        []
    }

    func fetchRelatedPlaces(contentId: String, limit: Int) async throws -> [RelatedPlace] {
        []
    }

    /// 태그 사전이 없으면 칩·집계 막대를 그리지 않는다 (빈 목록은 "없음"이지 오류가 아니다).
    func fetchReviewTags() async throws -> [ReviewTag] {
        []
    }

    /// 기본 구현은 실패한다. 조용히 빈 배열을 주면 사용자는 사진이 붙은 줄 알고 등록하게 된다.
    func uploadReviewImages(_ images: [Data]) async throws -> [URL] {
        throw FeedServiceError.writeUnsupported
    }

    /// 기본 구현은 실패한다. 조용히 성공하면 사용자는 등록됐다고 믿지만 서버엔 아무것도 남지 않는다.
    func submitReview(_ draft: ReviewDraft) async throws {
        throw FeedServiceError.writeUnsupported
    }

    /// 기본 구현은 실패한다. **빈 페이지를 돌려주면 안 된다** — 화면이 "아직 댓글이 없어요"를
    /// 그려 버리는데, 그건 이 소스가 댓글을 모른다는 사실과 다른 거짓말이다.
    /// (번들·목 데이터로 폴백하는 것도 금지다. 다른 리뷰의 댓글이 이 리뷰 밑에 붙는다.)
    func fetchReviewComments(reviewId: Int, page: Int, pageSize: Int) async throws -> ReviewCommentPage {
        throw FeedServiceError.commentsUnavailable
    }

    func submitReviewComment(reviewId: Int, body: String, authorNm: String?) async throws {
        throw FeedServiceError.commentsUnavailable
    }

    @discardableResult
    func updateReviewComment(reviewId: Int, commentId: Int, body: String) async throws -> ReviewComment {
        throw FeedServiceError.commentsUnavailable
    }

    func deleteReviewComment(reviewId: Int, commentId: Int) async throws {
        throw FeedServiceError.commentsUnavailable
    }
}

/// 저장 기능의 기본 동작 — **저장 개념이 없는 데이터 소스**(번들 폴백, 프리뷰 목)를 위한 것이다.
///
/// 목록은 빈 배열이 맞다(저장한 것이 없다). 쓰기는 조용히 성공시키지 않고 던진다 —
/// 오프라인에서 저장 버튼이 눌린 것처럼 보이면 사용자는 저장됐다고 믿고 앱을 닫는다.
extension FeedService {
    func fetchSavedPlaces(accessFeatures: [AccessibilityFeature]) async throws -> [Place] { [] }

    func setPlaceSaved(contentId: String, _ saved: Bool) async throws {
        throw FeedServiceError.writeUnsupported
    }

    /// 번들·목 데이터의 후기에는 서버 id 가 없어 좋아요를 붙일 대상이 없다.
    @discardableResult
    func setReviewLiked(reviewId: Int, _ liked: Bool) async throws -> (likeCount: Int, likedByMe: Bool) {
        throw FeedServiceError.writeUnsupported
    }
}

extension EnvironmentValues {
    @Entry var feedService: any FeedService = MockFeedService()
}

extension Array {
    /// 0-based 페이지 슬라이스. 범위를 벗어나면 빈 배열.
    func page(_ page: Int, size: Int) -> [Element] {
        let start = page * size
        guard start < count else { return [] }
        return Array(self[start..<Swift.min(start + size, count)])
    }
}
