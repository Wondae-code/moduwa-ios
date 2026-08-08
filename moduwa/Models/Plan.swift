import Foundation

// 피그마 "모두와 UI" 플랜 계열 시안 기준 스키마.
// 목록 391:232 / 상세 509:340·519:775 / 편집 519:987 / 새 플랜 플로우 372:409·519:1219·519:1343
//
// 전부 Codable이다 — 저장 방식(로컬 JSON·SwiftData·서버 API)이 아직 미정이라
// 어느 쪽으로 가도 그대로 직렬화되도록 값 타입으로 둔다.

// MARK: - 동반자 정보

/// 새 플랜 플로우 1/6에서 수집하고 목록 카드의 "팀 수정"으로 다시 편집하는 여행 동반자 정보.
/// 세 축 모두 다중 선택이다 (시안 1/6 선택시에서 20대+30대가 동시에 켜져 있다).
struct TravelParty: Hashable, Sendable, Codable {
    var ageGroups: Set<AgeGroup> = []
    var companions: Set<CompanionType> = []
    var mobilities: Set<MobilityMode> = []

    var isEmpty: Bool { ageGroups.isEmpty && companions.isEmpty && mobilities.isEmpty }
}

/// rawValue는 저장·전송용 안정 키, 표시 문구는 `label` — `AccessibilityFeature`와 같은 규칙.
enum AgeGroup: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case teens, twenties, thirties, forties, fifties, sixtiesPlus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teens: "10대"
        case .twenties: "20대"
        case .thirties: "30대"
        case .forties: "40대"
        case .fifties: "50대"
        case .sixtiesPlus: "60대 이상"
        }
    }
}

enum CompanionType: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case alone, partner, friends, family, parents, children, pet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alone: "혼자"
        case .partner: "연인과"
        case .friends: "친구와"
        case .family: "가족과"
        case .parents: "부모님과"
        case .children: "아이와"
        case .pet: "강아지와"
        }
    }
}

/// 이동 수단. 휠체어 선택은 접근성 필터링의 입력이 된다 — 공모전 핵심 주제라 단순 표시용이 아니다.
enum MobilityMode: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case car, walking, wheelchair

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car: "자차"
        case .walking: "뚜벅이"
        case .wheelchair: "휠체어"
        }
    }
}

// MARK: - 여행 지역

/// 새 플랜 플로우 2/6의 지역 12종. 행정구역이 아니라 시안이 묶어둔 여행지 단위라
/// (가평·양평, 통영·거제·남해처럼 복수 시군 묶음) 별도 enum으로 둔다.
/// 백엔드 조회에 쓸 시군구 코드 매핑은 지역 API 스펙이 정해지면 붙인다.
enum TravelRegion: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case gapyeongYangpyeong, gangneungSokcho, gyeongju, busan, yeosu, incheon
    case jeonju, jeju, chuncheonHongcheon, taean, tongyeongGeojeNamhae, pohangAndong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gapyeongYangpyeong: "가평·양평"
        case .gangneungSokcho: "강릉·속초"
        case .gyeongju: "경주"
        case .busan: "부산"
        case .yeosu: "여수"
        case .incheon: "인천"
        case .jeonju: "전주"
        case .jeju: "제주"
        case .chuncheonHongcheon: "춘천·홍천"
        case .taean: "태안"
        case .tongyeongGeojeNamhae: "통영·거제·남해"
        case .pohangAndong: "포항·안동"
        }
    }
}

// MARK: - 플랜

struct Plan: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var region: TravelRegion?
    var party: TravelParty
    /// 목록 카드 썸네일. 미지정이면 UI가 첫 장소 사진으로 폴백한다.
    var coverImageURL: URL?
    var days: [PlanDay]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        region: TravelRegion? = nil,
        party: TravelParty = TravelParty(),
        coverImageURL: URL? = nil,
        days: [PlanDay] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.region = region
        self.party = party
        self.coverImageURL = coverImageURL
        self.days = days
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Plan {
    /// 지난 여행 여부는 저장하지 않고 종료일로 판단한다 — 저장하면 날짜를 수정했을 때 어긋난다.
    /// 시안의 "지난 여행 - 날짜 수정시"(519:378)가 날짜만 고치면 카드가 되살아나는 것과 같은 동작.
    func isPast(asOf now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: endDate) < calendar.startOfDay(for: now)
    }

    /// 목록·상세 공통 "7월 26일 - 7월 27일"
    var dateRangeText: String {
        "\(PlanDateText.monthDay(startDate)) - \(PlanDateText.monthDay(endDate))"
    }
}

/// 한국어 전용 앱이라 DateFormatter 없이 직접 조립한다 —
/// 포매터를 static으로 들면 Sendable 예외를 달아야 하고, 로케일에 따라 표기가 흔들린다.
enum PlanDateText {
    private static let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    /// "7월 26일"
    static func monthDay(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)월 \(parts.day ?? 0)일"
    }

    /// "7/26 목"
    static func shortWithWeekday(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday = weekdays[((parts.weekday ?? 1) - 1) % 7]
        return "\(parts.month ?? 0)/\(parts.day ?? 0) \(weekday)"
    }
}

/// 하루치 일정. 날짜를 시작일+인덱스로 계산하지 않고 명시해 둔다 —
/// 기간 중 하루를 통째로 비우거나 나중에 하루를 끼워 넣는 편집을 막지 않기 위해서다.
struct PlanDay: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var date: Date
    var items: [PlanDayItem]

    init(id: UUID = UUID(), date: Date, items: [PlanDayItem] = []) {
        self.id = id
        self.date = date
        self.items = items
    }

    /// 번호 뱃지는 장소에만 붙는다 — 메모는 번호를 건너뛴다.
    var stops: [PlanStop] {
        items.compactMap { if case .stop(let stop) = $0 { stop } else { nil } }
    }

    /// items의 `index`에 있는 장소가 몇 번째 장소인지. 메모 자리면 nil.
    /// 번호가 items 인덱스와 어긋나므로(메모가 번호를 건너뛴다) 장소만 세어 매긴다.
    func stopNumber(at index: Int) -> Int? {
        guard items.indices.contains(index), case .stop = items[index] else { return nil }
        return items[...index].reduce(into: 0) { count, item in
            if case .stop = item { count += 1 }
        }
    }

    /// 시안 Day 헤더의 "7/26 목"
    var headerText: String { PlanDateText.shortWithWeekday(date) }
}

/// 하루의 타임라인에 장소와 메모가 섞인다. 메모는 추가하면 맨 아래에 붙고,
/// 그 뒤로는 장소 카드와 똑같이 드래그로 순서를 바꿀 수 있다 — 그래서 한 배열로 둔다.
enum PlanDayItem: Identifiable, Hashable, Sendable, Codable {
    case stop(PlanStop)
    case memo(PlanMemo)

    var id: UUID {
        switch self {
        case .stop(let stop): stop.id
        case .memo(let memo): memo.id
        }
    }
}

/// 일정에 담긴 장소 한 곳.
struct PlanStop: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var place: PlanPlace
    /// 바로 앞 장소에서 여기까지의 이동 거리 — 첫 장소는 nil.
    ///
    /// 시안은 이동 정보를 각 장소 프레임의 자식으로 두고 마지막 장소에서만 hidden 처리한다(519:631).
    /// 즉 시안 기준으로는 "다음 장소로의 이동"이지만, 렌더 결과는 앞으로부터의 이동과 동일하고
    /// (첫 장소만 비는 것과 마지막 장소만 비는 것이 같은 그림이 된다) 순서를 바꿨을 때
    /// 어느 구간이 무효가 되는지는 이쪽이 분명해서 방향을 뒤집어 잡았다.
    var travelFromPrevious: TravelLeg?

    init(id: UUID = UUID(), place: PlanPlace, travelFromPrevious: TravelLeg? = nil) {
        self.id = id
        self.place = place
        self.travelFromPrevious = travelFromPrevious
    }
}

/// 일정에 박제된 장소 정보.
///
/// 관광공사 데이터를 매번 다시 조회하지 않고 이름·카테고리·좌표를 그대로 들고 있는다 —
/// 지난 여행은 원본 POI가 사라져도 그대로 보여야 하고, 목록·상세가 오프라인에서도 그려져야 한다.
/// `contentID`가 있으면 원본을 다시 열 수 있고, nil이면 사용자가 만든 "나만의 장소"다.
struct PlanPlace: Hashable, Sendable, Codable {
    /// 관광공사 contentId. 나만의 장소는 nil.
    var contentID: String?
    var name: String
    /// 시안 부제목의 앞 조각 — "관광명소", "쇼핑", "숙소"
    var categoryLabel: String
    /// 시안 부제목의 뒤 조각 — "경주시내", "경북 경주". 나만의 장소는 nil이고 UI가 "나만의 장소"로 대체한다.
    var region: String?
    /// ⚠️ 상세 시안의 부제목은 `PlaceCategory` 4종을 벗어난다 — "쇼핑"(하나로 마트)은 아예 없는 케이스이고
    /// "관광명소"는 홈 피드의 "관광지"와 다른 표기다. 홈 피드 카테고리 칩·아이콘이 4종에 묶여 있어
    /// 케이스를 늘리지 않고, 매핑되지 않는 장소는 nil로 두고 표시에는 `categoryLabel`을 쓴다.
    var category: PlaceCategory?
    var imageURL: URL?
    /// 지도 핀과 "거리순 정렬"에 필요하다. 기존 `Place`에는 좌표가 없어 함께 채워야 한다.
    var latitude: Double?
    var longitude: Double?

    /// 목록에 없어 사용자가 직접 추가한 "나만의 장소". 상세 화면의 두 가지 표현이 모두 여기서 갈린다 —
    /// 번호 뱃지가 라임(딥그린 대신)으로 뜨고, 리뷰 버튼이 사라진다.
    var isCustom: Bool { contentID == nil }

    /// 리뷰 버튼 노출 여부. 나만의 장소는 관광공사 원본이 없어 리뷰를 붙일 대상이 없다.
    var showsReviewAction: Bool { !isCustom }

    /// 시안 부제목 "관광명소 · 경주시내" / "숙소 · 나만의 장소"
    var subtitle: String {
        "\(categoryLabel) · \(region ?? "나만의 장소")"
    }
}

/// 장소 사이 이동 거리.
///
/// 시안은 "도보 10분 520m"처럼 교통수단과 소요시간까지 적지만 그 둘은 경로 API가 있어야 나온다 —
/// 백엔드에 경로 API가 없고 카카오모빌리티도 미연동이라 지금은 거리만 다룬다(2026-08-02 결정).
/// 거리는 두 장소의 좌표만으로 구할 수 있어 자체 계산이 가능하다.
/// 경로 API가 붙으면 mode·minutes를 여기에 더하면 된다.
struct TravelLeg: Hashable, Sendable, Codable {
    var meters: Int

    /// 시안 표기 — 1km 미만은 "520m", 그 이상은 "58.6km"
    var distanceText: String {
        meters < 1_000 ? "\(meters)m" : String(format: "%.1fkm", Double(meters) / 1_000)
    }
}

struct PlanMemo: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}
