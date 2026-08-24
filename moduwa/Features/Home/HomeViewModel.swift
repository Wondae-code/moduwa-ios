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
    private(set) var canLoadMorePosts = false
    private(set) var isLoadingMoreReviews = false
    private var placesPage = 0
    private var reviewsPage = 0
    private var postsPage = 0

    /// "리뷰 더보기" 버튼을 띄울지. **둘 중 하나라도** 남아 있으면 띄운다 —
    /// 한 섹션에 후기와 게시글이 섞여 있어, 후기가 바닥나도 게시글이 남았으면 더 볼 것이 있다.
    var canLoadMoreFeed: Bool { canLoadMoreReviews || canLoadMorePosts }

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

    /// 게시글 첫 페이지. 서버에서 최신순으로 온다.
    ///
    /// ⚠️ 실패해도 화면을 실패로 만들지 않는다 — 게시글이 없거나 못 받아도 리뷰는 보여야 한다.
    /// 다만 **실패했으면 이미 받은 목록을 지우지 않는다**: 글을 쓰고 돌아와 다시 받는 길로도
    /// 쓰이는데, 그때 네트워크가 흔들리면 보고 있던 글이 통째로 사라진다.
    func loadPosts(using service: any PostService) async {
        guard let fresh = try? await service.fetchPosts(
            mineOnly: false, likedOnly: false,
            contentId: nil, limit: FeedPage.postSize, offset: 0)
        else { return }
        posts = fresh
        postsPage = 0
        canLoadMorePosts = fresh.count == FeedPage.postSize
    }
    private var isLoadingMorePlaces = false

    /// 로그인한 사람이 고른 무장애 요소. 추천 목록을 이 조건으로 좁힌다.
    ///
    /// 화면이 세션에서 받아 넣어 준다 — 뷰모델이 세션을 직접 알면 프리뷰가 세션 없이 돌지 않고,
    /// "지금 무엇으로 좁혀져 있는지"가 두 곳에 생긴다.
    private(set) var accessFeatures: [AccessibilityFeature] = []

    func loadInitial(using service: any FeedService, accessFeatures: [AccessibilityFeature]) async {
        self.accessFeatures = accessFeatures
        // TODO: API 연동 시 로딩/에러 상태 추가
        async let places = service.fetchRecommendedPlaces(
            category: selectedCategory, page: 0, accessFeatures: accessFeatures)
        async let reviews = service.fetchReviews(sort: reviewSort, page: 0)
        do {
            setPlaces(firstPage: try await places)
            setReviews(firstPage: try await reviews)
        } catch {
            // TODO: 에러 표시
        }
    }

    func selectCategory(_ category: PlaceCategory, using service: any FeedService) async {
        selectedCategory = category
        setPlaces(firstPage: (try? await service.fetchRecommendedPlaces(
            category: category, page: 0, accessFeatures: accessFeatures)) ?? [])
    }

    /// 무장애 요소가 바뀌었다 — 로그인·로그아웃, 또는 내 정보에서 직접 고쳤을 때.
    ///
    /// 목록을 **처음부터** 다시 받는다. 조건이 달라졌는데 이어 붙이면 앞부분은 옛 조건,
    /// 뒷부분은 새 조건인 목록이 된다.
    func applyAccessFeatures(
        _ features: [AccessibilityFeature], using service: any FeedService
    ) async {
        guard features != accessFeatures else { return }
        accessFeatures = features
        setPlaces(firstPage: (try? await service.fetchRecommendedPlaces(
            category: selectedCategory, page: 0, accessFeatures: features)) ?? [])
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
        guard let next = try? await service.fetchRecommendedPlaces(
            category: selectedCategory, page: nextPage, accessFeatures: accessFeatures) else { return }
        placesPage = nextPage
        // 카테고리를 오가는 동안 순서가 바뀌어 중복이 올 수 있어 id로 거른다
        let known = Set(places.map(\.id))
        places += next.filter { !known.contains($0.id) }
        canLoadMorePlaces = next.count == FeedPage.placeSize
    }

    /// "리뷰 더보기" — 후기와 **게시글을 함께** 이어 붙인다.
    ///
    /// ⚠️ 후기만 받으면 안 된다. 이 섹션은 두 종류가 섞인 한 목록인데 게시글이 첫 페이지에
    /// 멈춰 있으면, 더보기를 눌러도 게시글은 영원히 늘지 않는다 — 방금 쓴 글을 찾으려고
    /// 더보기를 누른 사람에게는 버튼이 고장난 것으로 보인다(2026-08-19 지적).
    ///
    /// 두 요청을 나란히 띄운다 — 서로를 기다릴 이유가 없다.
    func loadMoreFeed(feedService: any FeedService, postService: any PostService) async {
        guard canLoadMoreFeed, !isLoadingMoreReviews else { return }
        isLoadingMoreReviews = true
        defer { isLoadingMoreReviews = false }

        let nextReviewPage = reviewsPage + 1
        let nextPostPage = postsPage + 1

        // 바닥난 쪽은 부르지 않는다. 한쪽이 실패해도 다른 쪽은 이어 붙는다.
        async let moreReviews: [TravelReview]? = canLoadMoreReviews
            ? try? await feedService.fetchReviews(sort: reviewSort, page: nextReviewPage)
            : nil
        async let morePosts: [TravelPost]? = canLoadMorePosts
            ? try? await postService.fetchPosts(
                mineOnly: false, likedOnly: false, contentId: nil,
                limit: FeedPage.postSize, offset: nextPostPage * FeedPage.postSize)
            : nil

        if let next = await moreReviews {
            reviewsPage = nextReviewPage
            reviews += next
            canLoadMoreReviews = next.count == FeedPage.reviewSize
        }
        if let next = await morePosts {
            postsPage = nextPostPage
            // 새 글이 올라오면 offset 이 밀려 이미 가진 글이 다시 올 수 있다 —
            // `ForEach` 의 id 가 겹치면 터지므로 걸러 낸다(장소 검색의 이어 받기와 같은 이유).
            let known = Set(posts.map(\.id))
            posts += next.filter { !known.contains($0.id) }
            canLoadMorePosts = next.count == FeedPage.postSize
        }
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
