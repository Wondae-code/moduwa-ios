import SwiftUI

/// 피드 페이지 크기 상수
enum FeedPage {
    static let placeSize = 6
    static let reviewSize = 5
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
