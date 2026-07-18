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

    // 페이지네이션 상태
    private(set) var canLoadMorePlaces = false
    private(set) var canLoadMoreReviews = false
    private(set) var isLoadingMoreReviews = false
    private var placesPage = 0
    private var reviewsPage = 0
    private var isLoadingMorePlaces = false

    func loadInitial(using service: any FeedService) async {
        // TODO: API 연동 시 로딩/에러 상태 추가
        async let hero = service.fetchHeroRecommendation()
        async let places = service.fetchRecommendedPlaces(category: selectedCategory, page: 0)
        async let reviews = service.fetchReviews(sort: reviewSort, page: 0)
        do {
            self.hero = try await hero
            setPlaces(firstPage: try await places)
            setReviews(firstPage: try await reviews)
        } catch {
            // TODO: 에러 표시
        }
    }

    func selectCategory(_ category: PlaceCategory, using service: any FeedService) async {
        selectedCategory = category
        setPlaces(firstPage: (try? await service.fetchRecommendedPlaces(category: category, page: 0)) ?? [])
    }

    func selectSort(_ sort: ReviewSort, using service: any FeedService) async {
        reviewSort = sort
        setReviews(firstPage: (try? await service.fetchReviews(sort: sort, page: 0)) ?? [])
    }

    // MARK: - 더 불러오기

    /// "맞춤 추천 더보기" — 다음 페이지 장소를 이어 붙인다.
    func loadMorePlaces(using service: any FeedService) async {
        guard canLoadMorePlaces, !isLoadingMorePlaces else { return }
        isLoadingMorePlaces = true
        defer { isLoadingMorePlaces = false }

        let nextPage = placesPage + 1
        guard let next = try? await service.fetchRecommendedPlaces(category: selectedCategory, page: nextPage) else { return }
        placesPage = nextPage
        // 카테고리를 오가는 동안 순서가 바뀌어 중복이 올 수 있어 id로 거른다
        let known = Set(places.map(\.id))
        places += next.filter { !known.contains($0.id) }
        canLoadMorePlaces = next.count == FeedPage.placeSize
    }

    /// "리뷰 더보기" — 다음 페이지 리뷰를 이어 붙인다.
    func loadMoreReviews(using service: any FeedService) async {
        guard canLoadMoreReviews, !isLoadingMoreReviews else { return }
        isLoadingMoreReviews = true
        defer { isLoadingMoreReviews = false }

        let nextPage = reviewsPage + 1
        guard let next = try? await service.fetchReviews(sort: reviewSort, page: nextPage) else { return }
        reviewsPage = nextPage
        reviews += next
        canLoadMoreReviews = next.count == FeedPage.reviewSize
    }

    // MARK: - 페이지 초기화

    private func setPlaces(firstPage: [Place]) {
        places = firstPage
        placesPage = 0
        canLoadMorePlaces = firstPage.count == FeedPage.placeSize
    }

    private func setReviews(firstPage: [TravelReview]) {
        reviews = firstPage
        reviewsPage = 0
        canLoadMoreReviews = firstPage.count == FeedPage.reviewSize
    }
}
