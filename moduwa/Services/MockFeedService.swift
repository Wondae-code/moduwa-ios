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
