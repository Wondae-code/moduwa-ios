import Foundation

enum PlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case stay = "숙소"
    case food = "맛집"
    case attraction = "관광지"
    case festival = "축제·공연"

    var id: String { rawValue }

    /// 백엔드/JSON에서 쓰는 안정적인 키 (관광공사 contentTypeId: 32/39/12/15)
    var apiKey: String {
        switch self {
        case .stay: "stay"
        case .food: "food"
        case .attraction: "attraction"
        case .festival: "festival"
        }
    }

    /// Assets.xcassets의 아이콘 이름 (디자이너 제공 SVG)
    var iconName: String {
        switch self {
        case .stay: "hotel"
        case .food: "restaurant"
        case .attraction: "photo_camera"
        case .festival: "celebration"
        }
    }
}

enum AccessibilityFeature: String, Sendable, Decodable {
    case wheelchairAccessible
    case flatPath
    case barrierFreeRoom

    var label: String {
        switch self {
        case .wheelchairAccessible: "휠체어 접근"
        case .flatPath: "평탄 동선"
        case .barrierFreeRoom: "무장애 객실"
        }
    }
}

struct Place: Identifiable, Sendable {
    /// 관광공사 contentId (목 데이터는 "mock-*")
    let id: String
    let name: String
    let region: String
    /// 아직 평점 데이터 소스가 없다 — nil이면 UI에서 숨김
    let rating: Double?
    let accessibilityNote: String
    let feature: AccessibilityFeature
    let category: PlaceCategory
    let imageURL: URL?
}
