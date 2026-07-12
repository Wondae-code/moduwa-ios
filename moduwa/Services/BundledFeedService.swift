import Foundation

/// moduwa-backend PostgreSQL에서 조합해 번들한 HomeFeed.json을 읽는 구현.
/// (생성 스크립트: 백엔드 DB의 무장애 관광지 + 접근성 28속성 → 카테고리별 상위 장소)
/// JSON 구조가 그대로 향후 API 응답 스펙 제안이며, 서버가 생기면 APIFeedService로 교체한다.
struct BundledFeedService: FeedService {
    private struct HomeFeedDTO: Decodable {
        let hero: HeroDTO
        let placesByCategory: [String: [PlaceDTO]]
    }

    private struct HeroDTO: Decodable {
        let userName: String
        let headline: String
        let caption: String
        let tags: [String]
    }

    private struct PlaceDTO: Decodable {
        let id: String
        let name: String
        let region: String
        let imageURL: String
        let accessibilityNote: String
        let feature: AccessibilityFeature
    }

    enum LoadError: Error { case missingResource }

    private func loadFeed() throws -> HomeFeedDTO {
        guard let url = Bundle.main.url(forResource: "HomeFeed", withExtension: "json") else {
            throw LoadError.missingResource
        }
        return try JSONDecoder().decode(HomeFeedDTO.self, from: Data(contentsOf: url))
    }

    func fetchHeroRecommendation() async throws -> HeroRecommendation {
        let hero = try loadFeed().hero
        return HeroRecommendation(
            userName: hero.userName,
            headline: hero.headline,
            caption: hero.caption,
            tags: hero.tags
        )
    }

    func fetchRecommendedPlaces(category: PlaceCategory) async throws -> [Place] {
        let dtos = try loadFeed().placesByCategory[category.apiKey] ?? []
        return dtos.map { dto in
            Place(
                id: dto.id,
                name: dto.name,
                region: dto.region,
                rating: nil, // 평점 데이터 소스 없음
                accessibilityNote: dto.accessibilityNote,
                feature: dto.feature,
                category: category,
                imageURL: URL(string: dto.imageURL)
            )
        }
    }

    func fetchReviews(sort: ReviewSort) async throws -> [TravelReview] {
        // 백엔드에 리뷰/평점 데이터가 아직 없다 — 목으로 대체
        try await MockFeedService().fetchReviews(sort: sort)
    }
}
