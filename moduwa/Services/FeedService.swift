import SwiftUI

/// 홈 피드 데이터 소스.
/// 서버 연동 시 이 프로토콜을 구현한 APIFeedService를 만들고,
/// moduwaApp에서 `.environment(\.feedService, APIFeedService())` 한 줄로 교체한다.
protocol FeedService: Sendable {
    func fetchHeroRecommendation() async throws -> HeroRecommendation
    func fetchRecommendedPlaces(category: PlaceCategory) async throws -> [Place]
    func fetchReviews(sort: ReviewSort) async throws -> [TravelReview]
}

extension EnvironmentValues {
    @Entry var feedService: any FeedService = MockFeedService()
}
