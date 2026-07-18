import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var hero: HeroRecommendation?
    private(set) var places: [Place] = []
    private(set) var reviews: [TravelReview] = []
    private(set) var selectedCategory: PlaceCategory = .stay
    private(set) var reviewSort: ReviewSort = .recommended
    /// 새 알림 여부 — 뱃지 도트 표시용. 알림 API 연동 전까지 기본 false.
    private(set) var hasNewNotifications = false

    func loadInitial(using service: any FeedService) async {
        // TODO: API 연동 시 로딩/에러 상태 추가
        async let hero = service.fetchHeroRecommendation()
        async let places = service.fetchRecommendedPlaces(category: selectedCategory)
        async let reviews = service.fetchReviews(sort: reviewSort)
        do {
            self.hero = try await hero
            self.places = try await places
            self.reviews = try await reviews
        } catch {
            // TODO: 에러 표시
        }
    }

    func selectCategory(_ category: PlaceCategory, using service: any FeedService) async {
        selectedCategory = category
        places = (try? await service.fetchRecommendedPlaces(category: category)) ?? []
    }

    func selectSort(_ sort: ReviewSort, using service: any FeedService) async {
        reviewSort = sort
        reviews = (try? await service.fetchReviews(sort: sort)) ?? []
    }
}
