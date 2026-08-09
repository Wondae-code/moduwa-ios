import SwiftUI

/// 피드 페이지 크기 상수
enum FeedPage {
    static let placeSize = 6
    static let reviewSize = 5
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

    var errorDescription: String? {
        switch self {
        case .writeUnsupported: "지금은 후기를 등록할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .server(let message): message
        case .imageUploadFailed: "사진을 올리지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        case .nicknameRequired: "댓글에 표시될 이름을 입력해 주세요."
        case .commentsUnavailable: "이 후기의 댓글은 지금 볼 수 없어요."
        }
    }
}

/// 홈 피드 데이터 소스.
/// 서버 연동 시 이 프로토콜을 구현한 APIFeedService를 만들고,
/// moduwaApp에서 `.environment(\.feedService, APIFeedService())` 한 줄로 교체한다.
protocol FeedService: Sendable {
    func fetchHeroRecommendation() async throws -> HeroRecommendation
    /// `page`는 0부터. `FeedPage.placeSize`보다 적게 반환되면 마지막 페이지다.
    func fetchRecommendedPlaces(category: PlaceCategory, page: Int) async throws -> [Place]
    /// `page`는 0부터. `FeedPage.reviewSize`보다 적게 반환되면 마지막 페이지다.
    func fetchReviews(sort: ReviewSort, page: Int) async throws -> [TravelReview]
    /// 장소 상세 (무장애 속성 포함)
    func fetchPlaceDetail(contentId: String) async throws -> PlaceDetail

    // MARK: - 장소 상세 하단 3섹션

    /// 장소별 후기 집계 (평점·후기 수)
    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary
    /// 장소별 후기 목록. `page`는 0부터, `pageSize`보다 적게 오면 마지막 페이지다.
    ///
    /// 프로토콜 요구사항에는 기본 인자를 쓸 수 없어(Swift 제약) 호출부가 전부 명시한다.
    /// - `hasImage`: true면 사진이 있는 후기만 (`"사진/영상 후기만 보기"`)
    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool, page: Int, pageSize: Int
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
    ///   `nil` 을 보내면 서버가 기존 닉네임을 재사용하고, 정말 첫 작성이면 `.nicknameRequired` 를 던진다.
    func submitReviewComment(
        reviewId: Int, body: String, authorNm: String?, deviceId: String
    ) async throws
}

/// 장소 상세 하단 3섹션용 API는 라이브 서버에만 있다. 오프라인 폴백(`BundledFeedService`)에는
/// 대응 데이터가 없으므로 "이 소스에는 없음"을 뜻하는 기본 구현을 한 곳에 둔다
/// (구현체 3개에 같은 빈 함수를 복사하면 어느 게 진짜 미구현인지 구분되지 않는다).
extension FeedService {
    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary {
        .empty(contentId: contentId)
    }

    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool, page: Int, pageSize: Int
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

    func submitReviewComment(
        reviewId: Int, body: String, authorNm: String?, deviceId: String
    ) async throws {
        throw FeedServiceError.commentsUnavailable
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
