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

    /// 브랜드 가이드 픽토그램의 원본 viewBox 크기 — 아이콘마다 종횡비가 달라 고정 정사각형에 넣지 않는다.
    var iconViewBox: CGSize {
        switch self {
        case .wheelchairAccessible, .flatPath, .barrierFreeRoom: CGSize(width: 41.9674, height: 59.3729)
        case .hearingFriendly: CGSize(width: 63.3006, height: 63.4238)
        case .visuallyImpairedFriendly: CGSize(width: 58.1494, height: 61.8197)
        case .elderlyFriendly: CGSize(width: 27.2837, height: 63.5232)
        case .childFriendly: CGSize(width: 28.0514, height: 51.2362)
        }
    }

    /// 원형 뱃지(지름 `diameter`) 안에서의 아이콘 크기.
    /// 피그마 규칙: 픽토그램 종횡비를 유지한 채 대각선이 지름의 ≈0.82가 되도록 맞춘다
    /// (아이콘마다 폭/높이가 달라짐 — 34pt 뱃지에서 지체 16.3×23.0, 시각 19.1×20.3, 유아 13.3×24.3).
    func iconSize(inBadgeDiameter diameter: CGFloat) -> CGSize {
        let vb = iconViewBox
        let diagonal = (vb.width * vb.width + vb.height * vb.height).squareRoot()
        let target = diameter * 0.82
        return CGSize(width: target * vb.width / diagonal, height: target * vb.height / diagonal)
    }

    /// 종횡비를 유지한 채 높이 `height`에 맞춘 아이콘 크기 (인라인·알약 뱃지용).
    func iconSize(height: CGFloat) -> CGSize {
        CGSize(width: height * iconViewBox.width / iconViewBox.height, height: height)
    }
}

struct Place: Identifiable, Hashable, Sendable {
    /// 관광공사 contentId (목 데이터는 "mock-*")
    let id: String
    let name: String
    let region: String
    /// 아직 평점 데이터 소스가 없다 — nil이면 UI에서 숨김
    let rating: Double?
    let accessibilityNote: String
    let feature: AccessibilityFeature
    let category: PlaceCategory
    /// 통합 검색 API의 관광 타입 라벨. 홈 피드에는 별도 표기가 없어 `nil`이다.
    var categoryLabel: String? = nil
    let imageURL: URL?
}
