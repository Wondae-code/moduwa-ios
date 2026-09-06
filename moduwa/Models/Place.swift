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

/// rawValue가 한글 표시 문구라 저장 키로 쓸 수 없다 — 플랜 직렬화에는 안정 키인 `apiKey`를 쓴다.
extension PlaceCategory: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let match = PlaceCategory.allCases.first(where: { $0.apiKey == key }) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "알 수 없는 카테고리 키: \(key)"
            )
        }
        self = match
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiKey)
    }
}

/// 무장애 축. **같은 다섯 축이 서버에 세 벌의 다른 이름으로 저장돼 있다** — 이 enum 이 그
/// 세 벌을 다 들고 있는 유일한 자리다(2026-09-07 서버팀 052 회신에서 드러났다):
///
/// ```
/// 축     rawValue(이 파일)          serverAccessGroup   visitorTagCode
///        authors/posts.access_features   ?access=       review_tag_defs
/// 지체   wheelchairAccessible        wheelchair         visit_wheelchair
/// 시각   visuallyImpairedFriendly    visual             visit_visual
/// 청각   hearingFriendly             hearing            visit_hearing
/// 유아   childFriendly               infant             visit_infant   ← 어간이 다르다
/// 고령   elderlyFriendly             elderly            visit_elderly
/// ```
///
/// ⚠️ **세 벌 사이를 문자열 규칙으로 오갈 수 없다.** `visit_` 를 떼면 둘이 맞는 것처럼
/// 보이는데 그건 다섯 중 넷이 우연히 겹친 것이고, **유아 축은 `childFriendly` ↔ `infant`
/// 라 어떤 접두어·접미어 규칙으로도 못 간다.** 붙이거나 떼서 맞히려 들지 말 것 —
/// 아래 세 개의 `switch` 가 규칙이고, 표를 뒤집어 찾는 것(`init?(visitorTagCode:)`)이 규칙이다.
///
/// ⚠️ **이름을 바꾸면 세 곳에 정반대로 도착한다**(서버 `sql/052_tag_defs_restrict.sql` 주석과
/// 같은 내용을 반대 방향에서 적는다): `review_tag_defs` 는 FK 가 막아 **에러가 나고**,
/// `?access=` 는 필터가 그냥 **안 걸리고**, `access_features` 는 검증할 표가 없어 옛 문자열이
/// **그대로 남아 아무것과도 안 맞는다.** 셋 중 마지막이 050 에서 민감정보로 분류한 열이다.
/// 축 이름을 손대기 전에 서버팀에 알린다(양방향 약속, 2026-09-07).
///
/// `rawValue` 가 곧 서버 값이라 **case 이름을 바꾸는 것이 곧 스키마 변경이다** —
/// `APIAuthService` 와 `APIPostService` 가 `.map(\.rawValue)` 로 그대로 싣는다.
enum AccessibilityFeature: String, Sendable, Decodable, CaseIterable {
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

    /// **내가 어떤 사람인지**를 고르는 자리에서 쓰는 이름 — 온보딩 무장애정보 입력,
    /// 마이페이지의 "내 무장애정보"(시안 868:317 / 821:103).
    ///
    /// `label` 과 나누는 이유: `label` 은 **장소**를 설명하는 말이다("휠체어 접근"은 그 장소의
    /// 성질이다). 사람을 고르는 화면에 그 말을 쓰면 "나는 휠체어 접근이다"가 되어 어색하고,
    /// 시안도 그 자리에서만 "지체장애·시각장애·청각장애"로 적는다.
    var selfLabel: String {
        switch self {
        case .wheelchairAccessible, .flatPath, .barrierFreeRoom: "지체장애"
        case .visuallyImpairedFriendly: "시각장애"
        case .hearingFriendly: "청각장애"
        case .elderlyFriendly: "고령자"
        case .childFriendly: "유아동반"
        }
    }

    /// 서버 `/v1/barrier-free?access=` 가 아는 그룹 이름(백엔드 015 의 4개 플래그).
    ///
    /// `nil` 은 **서버가 그 축을 모른다**는 뜻이다:
    /// `flatPath`·`barrierFreeRoom` 은 서버 속성에서 파생되는 **표시용** 값이라 사람이 고르는
    /// 축이 아니다(`AccessibilityChoiceRow.choices` 에 없다).
    ///
    /// 고령자는 오래 `nil` 이었다 — 예전 서버가 관광공사 5유형 중 4개만 써서 축이 없었다.
    /// 2026-08-24 에 `elderly` 가 추가됐다(휠체어 대여·이동보조기기·승강기·주차 중 하나로 판정,
    /// 전국 6,231곳). 이제 다른 축과 똑같이 좁혀진다.
    var serverAccessGroup: String? {
        switch self {
        case .wheelchairAccessible: "wheelchair"
        case .visuallyImpairedFriendly: "visual"
        case .hearingFriendly: "hearing"
        case .childFriendly: "infant"
        case .elderlyFriendly: "elderly"
        case .flatPath, .barrierFreeRoom: nil
        }
    }

    /// 방문 조건 태그 코드에서 축을 되찾는다 — 후기에 붙은 태그(`visit_wheelchair` 등)를
    /// 무장애 축으로 되돌릴 때 쓴다. 홈 추천 정렬이 "이 후기가 나와 같은 조건인가"를
    /// 묻는 데 필요하다(`HomeFeedItem.accessFeatures`).
    ///
    /// 위 `visitorTagCode` 를 뒤집어 찾는다 — 코드 표를 두 번 적으면 한쪽만 고쳐질 수 있다.
    init?(visitorTagCode code: String) {
        guard let match = Self.allCases.first(where: { $0.visitorTagCode == code }) else { return nil }
        self = match
    }

    /// 후기의 **방문 조건 태그** 코드(서버 051). 프로필 다섯 축과 1:1 이다.
    ///
    /// ⚠️ 이 값으로 태그를 **자동 저장하지 않는다.** 프로필은 비공개인데 태그는 공개라,
    /// 자동으로 붙이면 프로필을 대신 공개하는 것이 된다. 작성 화면에서 **미리 체크해 보여
    /// 주기만** 하고 결정은 글마다 본인이 한다(서버팀도 같은 당부를 했다).
    var visitorTagCode: String? {
        switch self {
        case .wheelchairAccessible: "visit_wheelchair"
        case .visuallyImpairedFriendly: "visit_visual"
        case .hearingFriendly: "visit_hearing"
        case .childFriendly: "visit_infant"
        case .elderlyFriendly: "visit_elderly"
        case .flatPath, .barrierFreeRoom: nil
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
    /// 좌표(`mapy`=위도, `mapx`=경도). 플랜 일정에 담을 때 지도 핀·구간 거리에 쓴다.
    ///
    /// 기본값을 둔 이유는 이 값을 채우지 않는 데이터 소스(목 데이터 등)를 그대로 두기 위해서다.
    /// 원본에 좌표가 없는 장소도 있어 서버가 `null`을 주기도 한다.
    var latitude: Double? = nil
    var longitude: Double? = nil
}
