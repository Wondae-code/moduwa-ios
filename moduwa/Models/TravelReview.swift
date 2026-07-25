import Foundation

enum ReviewSort: String, CaseIterable, Sendable {
    case recommended = "추천"
    case latest = "최신"
}

struct TravelReview: Identifiable, Hashable, Sendable {
    let id = UUID()
    let author: String
    let location: String
    let body: String
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    /// 접근성 정보가 검증된 리뷰 (카드 좌상단 ♿ 뱃지)
    let isAccessibilityVerified: Bool
    /// 리뷰 사진 (카드 상단 2분할 슬롯 — 부족하면 플레이스홀더)
    var imageURLs: [URL] = []
    /// 방문한 장소의 관광공사 contentId — 있으면 리뷰 상세의 '방문한 장소' 카드가 장소 상세로 연결된다.
    var contentId: String? = nil
}
