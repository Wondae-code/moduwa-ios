import Foundation

/// API 연동 전까지 쓰는 목 구현 — 데이터는 MockData에서 가져온다.
struct MockFeedService: FeedService {
    func fetchHeroRecommendation() async throws -> HeroRecommendation {
        MockData.heroRecommendation
    }

    func fetchRecommendedPlaces(category: PlaceCategory, page: Int) async throws -> [Place] {
        // TODO: 실서버에서는 카테고리 필터가 적용된다. 목은 카테고리별 데이터가 없어 동일 목록 반환.
        MockData.recommendedPlaces.page(page, size: FeedPage.placeSize)
    }

    func fetchReviews(sort: ReviewSort, page: Int) async throws -> [TravelReview] {
        let sorted: [TravelReview] = switch sort {
        case .recommended: Self.reviewPool
        case .latest: Self.reviewPool.sorted { $0.createdAt > $1.createdAt }
        }
        return sorted.page(page, size: FeedPage.reviewSize)
    }

    /// 무한 스크롤 확인용 목 리뷰 풀 — 기본 2건을 변형해 17건으로 늘린다.
    /// (백엔드에 리뷰 데이터가 아직 없어 스크롤 동작 검증 용도)
    private static let reviewPool: [TravelReview] = {
        let base = MockData.reviews
        return (0..<17).map { i in
            let source = base[i % base.count]
            return TravelReview(
                author: i < base.count ? source.author : "\(source.author)\(i)",
                location: source.location,
                body: source.body,
                likeCount: max(1, source.likeCount - i * 37),
                commentCount: max(0, source.commentCount - i * 3),
                createdAt: source.createdAt.addingTimeInterval(-Double(i) * 86_400),
                isAccessibilityVerified: source.isAccessibilityVerified
            )
        }
    }()
}
