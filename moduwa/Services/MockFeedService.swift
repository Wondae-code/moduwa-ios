import Foundation

/// API 연동 전까지 쓰는 목 구현 — 데이터는 MockData에서 가져온다.
struct MockFeedService: FeedService {

    func fetchRecommendedPlaces(
        category: PlaceCategory, page: Int, accessFeatures: [AccessibilityFeature]
    ) async throws -> [Place] {
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

    func fetchPlaceDetail(contentId: String) async throws -> PlaceDetail {
        // Figma "추천장소 B" 시안(불국사) 그대로 — 프리뷰·시연용
        PlaceDetail(
            id: contentId,
            name: "불국사",
            address: "경북 경주시 불국로 385 (진현동)",
            imageURL: nil,
            rating: 4.9,
            reviewCount: 233,
            overview: "경주 토함산에 자리잡은 불국사는 신라 경덕왕 10년(751)에 당시 재상이었던 김대성이 짓기 시작하여, 혜공왕 10년(774)에 완성하였다. 이후 조선 선조 26년(1593)에 왜의 침입으로 대부분의 건물이 불타버렸다. 이후 극락전, 자하문, 범영루 등의 일부 건물만이 그 명맥을 이어오다가 1969년에서 1973년에 걸친 발굴조사 뒤 복원을 하여 현재의 모습을 갖추게 되었다.",
            info: [
                .init(label: "운영시간", value: "24시간 운영 / 주말 18시까지"),
                .init(label: "휴무일", value: "공휴일 휴무"),
                .init(label: "주차정보", value: "무료주차 이용가능"),
                .init(label: "이용요금", value: "성인 5,000원 / 어린이 1,000원"),
                .init(label: "전화번호", value: "054-746-9913"),
                .init(label: "홈페이지", value: "http://www.bulguksa.or.kr", isLink: true),
            ],
            accessibilityGroups: [
                .init(feature: .wheelchairAccessible, notes: ["휠체어 경사로가 있어요", "휠체어 대여서비스가 있어요"]),
                .init(feature: .visuallyImpairedFriendly, notes: ["점자블록 있어요"]),
                .init(feature: .hearingFriendly, notes: ["보청기 대여가 가능해요"]),
            ],
            cautionTags: ["아이동반주의", "애견동반주의"],
            latitude: 35.789885,
            longitude: 129.331920
        )
    }

    // MARK: - 장소 상세 하단 3섹션 (프리뷰·시연용)

    /// 시안(333:1344 "4.3", 333:1362 "후기 235")과 `fetchPlaceDetail`의 목 값이 어긋나지 않게
    /// 상세 목 데이터와 같은 4.9 / 233을 돌려준다.
    func fetchReviewSummary(contentId: String) async throws -> PlaceReviewSummary {
        PlaceReviewSummary(
            contentId: contentId, averageRating: 4.9, reviewCount: 233, ratedCount: 229,
            // 인원 많은 순 — 서버 정렬과 같은 순서로 준다.
            // 1위와 꼬리의 차이가 큰 값을 섞어 막대 길이 비율을 프리뷰에서 확인한다.
            tags: zip(Self.tagPool, [118, 74, 41, 21, 9]).map(ReviewTagCount.init)
        )
    }

    func fetchReviewTags() async throws -> [ReviewTag] {
        Self.tagPool
    }

    func fetchPlaceReviews(
        contentId: String, sort: PlaceReviewSort, hasImage: Bool, page: Int, pageSize: Int
    ) async throws -> [TravelReview] {
        let pool = hasImage ? Self.reviewPool.filter { !$0.imageURLs.isEmpty } : Self.reviewPool
        let sorted = switch sort {
        case .likes: pool.sorted { $0.likeCount > $1.likeCount }
        case .latest: pool.sorted { $0.createdAt > $1.createdAt }
        }
        return sorted.page(page, size: pageSize)
    }

    /// 목은 네트워크가 없다 — 업로드는 원본 사진 URL을 그대로 돌려줘 작성 화면의 성공 경로만 확인한다.
    func uploadReviewImages(_ images: [Data]) async throws -> [URL] {
        images.indices.compactMap { _ in MockData.reviews.first?.imageURLs.first }
    }

    /// `GET /v1/review-tags` 실제 응답과 같은 코드·문구·아이콘.
    /// 아이콘이 없는 태그(가성비)를 일부러 섞어 "텍스트만 그리는" 경로를 프리뷰에서 확인한다.
    static let tagPool: [ReviewTag] = [
        .init(code: "barrier_free", label: "무장애 친화적이에요", shortLabel: "무장애", icon: "access_wheelchair"),
        .init(code: "silver", label: "어르신과 함께하기 좋아요", shortLabel: "실버", icon: "access_elderly"),
        .init(code: "kids", label: "아이와 함께하기 좋아요", shortLabel: "키즈", icon: "access_child"),
        .init(code: "taste", label: "음식이 맛있어요", shortLabel: "맛", icon: "category_food"),
        .init(code: "value", label: "가성비가 좋아요", shortLabel: "가성비", icon: nil),
    ]

    func fetchRelatedPlaces(contentId: String, limit: Int) async throws -> [RelatedPlace] {
        Array(Self.relatedPool.prefix(limit))
    }

    /// 목은 네트워크가 없다 — 등록은 성공으로 처리해 작성 화면의 성공 경로를 프리뷰에서 볼 수 있게 한다.
    func submitReview(_ draft: ReviewDraft) async throws {}

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
                isAccessibilityVerified: source.isAccessibilityVerified,
                imageURLs: source.imageURLs,
                contentId: source.contentId,
                // 별점 없이 남긴 후기(3번째마다 nil)도 섞어 별 행이 빠지는 경우를 프리뷰에서 확인한다
                rating: i % 3 == 2 ? nil : 5 - (i % 2),
                authorLevel: 7 - (i % 5),
                authorReviewCount: 3 + i,
                // 태그가 없는 후기(4번째마다)도 섞어 뱃지 줄이 빠지는 경우를 확인한다
                tags: i % 4 == 3 ? [] : Array(Self.tagPool.prefix(1 + i % 3)),
                wouldRevisit: i % 3 == 2 ? nil : (i % 2 == 0)
            )
        }
    }()

    /// 시안 352:54의 카드 3장 그대로
    private static let relatedPool: [RelatedPlace] = [
        RelatedPlace(id: "mock-related-1", name: "동궁과 월지", region: "경북 경주시 인왕동",
                     imageURL: nil, features: [.wheelchairAccessible, .visuallyImpairedFriendly]),
        RelatedPlace(id: "mock-related-2", name: "광안리 해수욕장", region: "부산 광안리",
                     imageURL: nil, features: [.wheelchairAccessible]),
        RelatedPlace(id: "mock-related-3", name: "국립경주박물관", region: "경북 경주시 인왕동",
                     imageURL: nil, features: [.wheelchairAccessible, .childFriendly]),
    ]
}
