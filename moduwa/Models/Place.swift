import Foundation

enum PlaceCategory: String, CaseIterable, Identifiable, Sendable {
    case stay = "숙소"
    case food = "맛집"
    case attraction = "관광지"
    case festival = "축제·공연·전시"

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

    /// Assets.xcassets의 아이콘 이름 (Figma "모두와 UI" 커스텀 아이콘)
    var iconName: String {
        switch self {
        case .stay: "category_stay"
        case .food: "category_food"
        case .attraction: "category_attraction"
        case .festival: "category_festival"
        }
    }
}

enum AccessibilityFeature: String, Sendable, Decodable {
    case wheelchairAccessible
    case flatPath
    case barrierFreeRoom
    // 브랜드 가이드 접근성 아이콘 5종에 맞춘 확장 (백엔드 속성 연동은 추후)
    case hearingFriendly
    case visuallyImpairedFriendly
    case elderlyFriendly
    case childFriendly

    var label: String {
        switch self {
        case .wheelchairAccessible: "휠체어 접근"
        case .flatPath: "평탄 동선"
        case .barrierFreeRoom: "무장애 객실"
        case .hearingFriendly: "청각 지원"
        case .visuallyImpairedFriendly: "시각 지원"
        case .elderlyFriendly: "고령자 친화"
        case .childFriendly: "유아 동반"
        }
    }

    /// 뱃지 아이콘 (Figma 접근성 아이콘 5종)
    var iconName: String {
        switch self {
        case .wheelchairAccessible, .flatPath, .barrierFreeRoom: "access_wheelchair"
        case .hearingFriendly: "access_hearing"
        case .visuallyImpairedFriendly: "access_visual"
        case .elderlyFriendly: "access_elderly"
        case .childFriendly: "access_child"
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
