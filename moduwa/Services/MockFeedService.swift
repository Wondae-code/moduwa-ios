import Foundation

/// API 연동 전까지 쓰는 목 구현 — 데이터는 MockData에서 가져온다.
struct MockFeedService: FeedService {
    func fetchHeroRecommendation() async throws -> HeroRecommendation {
        MockData.heroRecommendation
    }

    func fetchRecommendedPlaces(category: PlaceCategory) async throws -> [Place] {
        // TODO: 실서버에서는 카테고리 필터가 적용된다. 목은 카테고리별 데이터가 없어 동일 목록 반환.
        MockData.recommendedPlaces
    }

    func fetchReviews(sort: ReviewSort) async throws -> [TravelReview] {
        switch sort {
        case .recommended:
            MockData.reviews
        case .latest:
            MockData.reviews.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
