import Foundation

/// "함께 가볼만한 곳" 카드 (`GET /v1/barrier-free/:contentId/related`) — Figma 352:48 / 352:54
///
/// 홈 피드의 `Place`를 재사용하지 않는 이유: 시안 카드는 접근성 뱃지·안내 문구 없이 사진·이름·지역만
/// 쓰는데, `Place`가 요구하는 `accessibilityNote`와 단일 `feature`가 이 응답에는 없다
/// (대신 유형별 boolean 4개가 온다). 없는 값을 빈 문자열로 채워 넣는 대신 응답 모양에 맞춘 타입을 둔다.
struct RelatedPlace: Identifiable, Hashable, Sendable {
    /// 관광공사 contentId
    let id: String
    let name: String
    /// 서버가 "경북 경주시" 형태로 이미 축약해 준다 — 앱에서 `shortRegion`으로 다시 자르지 않는다
    let region: String
    let imageURL: URL?
    /// 지원하는 접근성 유형. 카드에는 그리지 않고 VoiceOver 라벨에만 덧붙인다
    /// (시안 카드에 뱃지 자리가 없다 — 화면에서 사라진 정보를 스크린리더에서도 지우지 않기 위함).
    let features: [AccessibilityFeature]

    /// 장소 상세로 넘길 최소 `Place`. 상세 값은 이동 후 contentId로 다시 조회한다.
    var place: Place {
        Place(
            id: id,
            name: name,
            region: region,
            rating: nil,
            accessibilityNote: "",
            feature: features.first ?? .wheelchairAccessible,
            category: .attraction,
            imageURL: imageURL
        )
    }
}
