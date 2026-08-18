import Foundation
import Observation

@MainActor
/// 홈 "여행자 리뷰" 섹션의 한 줄. 리뷰와 게시글이 같은 자리에 섞인다.
enum HomeFeedItem: Identifiable, Hashable {
    case review(TravelReview)
    case post(TravelPost)

    /// 두 종류의 id 가 겹치지 않게 접두사를 붙인다.
    var id: String {
        switch self {
        case .review(let review): "review-\(review.id)"
        case .post(let post): "post-\(post.id)"
        }
    }

    /// `nonisolated` — 정렬 클로저는 액터 밖에서 돌아간다. 값 타입 두 개를 읽을 뿐이라
    /// 메인 액터에 묶어 둘 이유가 없다(enum 전체가 `@MainActor` 다).
    nonisolated var createdAt: Date {
        switch self {
        case .review(let review): review.createdAt
        case .post(let post): post.createdAt
        }
    }

    /// 서버 `recommended` 정렬이 보는 값 — `like_count + comment_count`.
    nonisolated var engagement: Int {
        switch self {
        case .review(let review): review.likeCount + review.commentCount
        case .post(let post): post.likeCount + post.commentCount
        }
    }
}

@Observable
final class HomeViewModel {
    private(set) var hero: HeroRecommendation?
    private(set) var places: [Place] = []
    private(set) var reviews: [TravelReview] = []
    /// 홈 "여행자 리뷰" 섹션에 함께 싣는 게시글.
    ///
    /// 리뷰와 별도로 들고 있다가 `feedItems` 에서 섞는다 — 두 목록의 페이지네이션이
    /// 서로 다르기 때문이다(리뷰는 정렬 옵션이 있고 게시글은 최신순뿐이다).
    private(set) var posts: [TravelPost] = []
    private(set) var selectedCategory: PlaceCategory = .stay
    private(set) var reviewSort: ReviewSort = .recommended

    // 페이지네이션 상태
    private(set) var canLoadMorePlaces = false
    private(set) var canLoadMoreReviews = false
    private(set) var isLoadingMoreReviews = false
    private var placesPage = 0
    private var reviewsPage = 0

    /// 홈 "여행자 리뷰" 섹션에 그릴 것 — 리뷰와 게시글을 **고른 정렬대로 섞은** 목록.
    ///
    /// 두 목록을 각각 받아 와 화면에서 합치므로, 서버가 리뷰에 매긴 순서를 게시글에도
    /// **같은 식으로** 적용해야 한다. 그러지 않으면 한 섹션 안에서 두 기준이 섞여
    /// 위아래 순서가 뒤죽박죽으로 보인다. 서버 `REVIEW_ORDERS`(app.ts)와 짝을 맞춘다:
    ///
    /// - `.latest` → `created_at desc`
    /// - `.recommended` → `(like_count + comment_count) desc, created_at desc`
    ///
    /// ⚠️ 정렬 규칙을 서버에서 바꾸면 이쪽도 함께 고쳐야 한다. 홈 정렬은 리뷰만 서버에
    /// 맡기고 게시글은 늘 최신순으로 받기 때문에(정렬 파라미터가 없다) 합치는 자리에서
    /// 규칙을 다시 적용하는 수밖에 없다.
    var feedItems: [HomeFeedItem] {
        let merged = reviews.map(HomeFeedItem.review) + posts.map(HomeFeedItem.post)
        switch reviewSort {
        case .latest:
            return merged.sorted { $0.createdAt > $1.createdAt }
        case .recommended:
            // 반응 수가 같으면 최신 글이 위로 — 서버의 두 번째 정렬 키와 같다.
            return merged.sorted {
                $0.engagement == $1.engagement
                    ? $0.createdAt > $1.createdAt
                    : $0.engagement > $1.engagement
            }
        }
    }

    /// 게시글 목록. 서버에서 최신순으로 온다.
    ///
    /// ⚠️ 실패해도 화면을 실패로 만들지 않는다 — 게시글이 없거나 못 받아도 리뷰는 보여야 한다.
    func loadPosts(using service: any PostService) async {
        posts = (try? await service.fetchPosts(
            mineOnly: false, likedOnly: false, contentId: nil, limit: 10, offset: 0)) ?? []
    }
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
