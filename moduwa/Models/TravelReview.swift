import Foundation

enum ReviewSort: String, CaseIterable, Sendable {
    case recommended = "추천"
    case latest = "최신"
}

/// 장소 후기 목록의 정렬. 홈 피드의 `ReviewSort`와 **다른 집합**이라 따로 둔다.
///
/// - 화면의 "좋아요 순"은 서버 `sort=likes`다. 홈의 `recommended`는 좋아요+댓글을 함께 보는
///   다른 정렬이라 이름만 비슷할 뿐 결과가 다르다.
/// - `ReviewSort`에 `.likes`를 더하면 `CaseIterable`을 그대로 쓰는 홈 정렬 피커
///   (`HomeView`)에 "좋아요"가 끼어든다. 두 화면의 선택지가 서로 다르므로 enum을 나눈다.
enum PlaceReviewSort: String, CaseIterable, Sendable {
    case likes = "좋아요 순"
    case latest = "최신 순"

    /// 서버 쿼리 값
    var apiValue: String {
        switch self {
        case .likes: "likes"
        case .latest: "latest"
        }
    }
}

struct TravelReview: Identifiable, Hashable, Sendable {
    let id = UUID()
    /// 서버 리뷰 id (`GET /v1/reviews` 항목의 `id`). 댓글 API가 `/v1/reviews/:reviewId/comments`
    /// 형태라 이 값이 없으면 댓글을 읽지도 쓰지도 못한다.
    ///
    /// `id`(UUID)를 이 값으로 대체하지 않는 이유:
    /// - `id`는 `Identifiable`·`NavigationLink(value:)`·`ForEach`의 키로 이미 쓰이고 있는데,
    ///   번들/목 데이터의 리뷰에는 서버 id가 아예 없다. 옵셔널을 키로 쓸 수 없다.
    /// - 두 리뷰가 같은 내용이어도 UUID가 달라 목록에서 구분된다. 서버 id로 바꾸면
    ///   id 없는 리뷰들이 전부 같은 키가 되어 `ForEach`가 뭉갠다.
    /// 그래서 화면 식별용 `id`와 서버 식별용 `serverId`를 나눠 둔다.
    var serverId: Int? = nil
    let author: String
    let location: String
    let body: String
    /// 낙관적 갱신으로 바뀔 수 있어 var 다.
    var likeCount: Int
    let commentCount: Int
    /// 보는 사람이 좋아요를 눌렀는지(서버 `likedByMe`). 하트를 채운 상태로 그리는 근거.
    /// 번들·목 데이터는 항상 false.
    var likedByMe: Bool = false
    let createdAt: Date
    /// 접근성 정보가 검증된 리뷰 (카드 좌상단 ♿ 뱃지)
    let isAccessibilityVerified: Bool
    /// 리뷰 사진 (카드 상단 2분할 슬롯 — 부족하면 플레이스홀더)
    var imageURLs: [URL] = []
    /// 방문한 장소의 관광공사 contentId — 있으면 리뷰 상세의 '방문한 장소' 카드가 장소 상세로 연결된다.
    var contentId: String? = nil
    /// 작성자가 매긴 별점(1~5). 별점 없이 본문만 남긴 후기가 있어 옵셔널이다 — nil이면 별 행을 그리지 않는다.
    var rating: Int? = nil
    /// 서버 `authorInfo.level` — 시안(333:1394)의 "Level 7" 자리. 어떤 계산식으로도 시안 값을
    /// 재현할 수 없는 더미라 서버가 주는 값을 그대로 쓴다.
    var authorLevel: Int? = nil
    /// 서버 `authorInfo.reviewCount` — 시안(333:1396)의 "3개의 리뷰" 자리
    var authorReviewCount: Int? = nil
    /// 작성자가 고른 후기 태그. 후기 한 줄에서는 `shortLabel` 뱃지로 그린다.
    var tags: [ReviewTag] = []
    /// "재방문을 하고 싶어요" 응답. **세 상태를 구분한다** — true/false/미응답(nil).
    /// 미응답을 false로 접으면 "다시 오지 않겠다"는 뜻이 되어 버린다.
    var wouldRevisit: Bool? = nil
}

/// 장소별 후기 집계 (`GET /v1/reviews/summary?contentId=`).
///
/// `PlaceDetail`에 합치지 않고 따로 둔 이유:
/// - 출처가 다른 엔드포인트다. 무장애 상세(`/v1/barrier-free/:id`)에는 평점 필드가 아예 없다.
/// - 상세는 정적이지만 이 집계는 후기를 쓰면 바뀐다. 한 타입에 묶으면 후기 등록 후 상세까지
///   다시 받아야 하고, 둘 중 하나만 실패해도 화면이 통째로 비어 버린다.
///
/// `PlaceDetail.rating`/`reviewCount`는 목·프리뷰용 값으로 남겨 두고, 화면에서는 집계가 도착하면
/// 그것을 우선한다(`PlaceDetailView.averageRating`).
struct PlaceReviewSummary: Sendable, Hashable {
    let contentId: String
    /// 별점을 남긴 후기만의 평균. 별점이 하나도 없으면 nil
    let averageRating: Double?
    /// 후기 전체 수 (별점 없는 후기 포함)
    let reviewCount: Int
    /// `averageRating`의 분모 — 별점을 남긴 후기 수
    let ratedCount: Int
    /// 태그별 집계. 서버가 인원 많은 순으로 정렬해 준다.
    ///
    /// "N명 이상만 노출" 같은 임계값은 두지 않는다. 시연 데이터가 태그당 1~2명이라
    /// 임계값을 걸면 막대가 통째로 사라져 화면이 비어 버린다.
    var tags: [ReviewTagCount] = []

    static func empty(contentId: String) -> Self {
        .init(contentId: contentId, averageRating: nil, reviewCount: 0, ratedCount: 0, tags: [])
    }
}
