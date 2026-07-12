import Foundation

/// API 연동 전까지 사용하는 목 데이터 — 내용은 Figma 메인화면 시안 그대로
enum MockData {
    static let heroRecommendation = HeroRecommendation(
        userName: "모두와",
        headline: "휠체어로 이용하기 좋은\n여행지를 추천드려요",
        caption: "같은 태그의 여행자들이 추천한 코스예요",
        tags: ["#경사로", "#휠체어", "#효도여행"]
    )

    static let recommendedPlaces: [Place] = [
        Place(
            id: "mock-stay-1",
            name: "서귀포 무장애 펜션",
            region: "제주 서귀포시",
            rating: 4.9,
            accessibilityNote: "전 객실 휠체어 진입 가능",
            feature: .wheelchairAccessible,
            category: .stay,
            imageURL: nil
        ),
        Place(
            id: "mock-stay-2",
            name: "강릉 오션뷰 호텔",
            region: "강원 강릉시",
            rating: 4.7,
            accessibilityNote: "엘리베이터·경사로 완비",
            feature: .wheelchairAccessible,
            category: .stay,
            imageURL: nil
        ),
        Place(
            id: "mock-stay-3",
            name: "경주 한옥 스테이 담",
            region: "경북 경주시",
            rating: 4.8,
            accessibilityNote: "마당까지 무단차 연결",
            feature: .flatPath,
            category: .stay,
            imageURL: nil
        ),
        Place(
            id: "mock-stay-4",
            name: "해운대 베이 리조트",
            region: "부산 해운대구",
            rating: 4.6,
            accessibilityNote: "전용 주차·램프 제공",
            feature: .barrierFreeRoom,
            category: .stay,
            imageURL: nil
        ),
    ]

    static let reviews: [TravelReview] = [
        TravelReview(
            author: "평지러버",
            location: "강릉 안목해변",
            body: "음성안내 서비스가 잘 되어있네요~!",
            likeCount: 761,
            commentCount: 42,
            createdAt: Date(timeIntervalSince1970: 1_781_000_000), // 2026-06-10경
            isAccessibilityVerified: true
        ),
        TravelReview(
            author: "효도여행중",
            location: "강릉 안목해변",
            body: "부모님 모시고 편안하게 다녀왔습니다. 단차가 없어서 휠체어로 다니기에 무리없네요.",
            likeCount: 3001,
            commentCount: 64,
            createdAt: Date(timeIntervalSince1970: 1_783_200_000), // 2026-07-05경
            isAccessibilityVerified: true
        ),
    ]
}
