import Foundation

// 피그마 "모두와 UI" 플랜 계열 시안 기준 스키마.
// 목록 391:232 / 상세 509:340·519:775 / 편집 519:987 / 새 플랜 플로우 372:409·519:1219·519:1343
//
// 저장은 서버(`/v1/plans`)로 정해졌다 — `APIPlanService` 참고.
// 다만 서버 표기(날짜 두 형식, `kind` 판별자)는 이 타입들이 아니라 그쪽 DTO가 안다.
// 여기 붙은 Codable은 도메인 모델의 직렬화일 뿐 **전송 형식이 아니다**.

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

extension TravelRegion {
    /// 추천 코스가 쓰는 서버 슬러그(`region_slugs`).
    ///
    /// ⚠️ 앱의 지역은 "강릉·속초"처럼 **여러 시군을 묶은** 이름인데 서버 슬러그는 시군 하나다.
    /// v1 은 앞에 적힌 대표 도시로 보낸다 — 강릉·속초를 고르면 강릉에서 고른다.
    /// 두 시군을 함께 보려면 서버가 여러 시군구 코드를 받아야 한다(v2).
    var courseSlug: String {
        switch self {
        case .gapyeongYangpyeong: "gapyeong"
        case .gangneungSokcho: "gangneung"
        case .gyeongju: "gyeongju"
        case .busan: "busan"
        case .yeosu: "yeosu"
        case .incheon: "incheon"
        case .jeonju: "jeonju"
        case .jeju: "jeju"
        case .chuncheonHongcheon: "chuncheon"
        case .taean: "taean"
        case .tongyeongGeojeNamhae: "tongyeong"
        case .pohangAndong: "andong"
        }
    }
}

extension TravelParty {
    /// 추천 코스가 쓰는 동반자 코드(`kids`·`pet`·`elderly`·`couple`·`friends`·`solo`).
    ///
    /// 앱이 더 잘게 묻는다 — "가족과"처럼 서버에 대응이 없는 것은 **보내지 않는다.**
    /// 억지로 가까운 값에 붙이면(가족 → kids) 아이 없는 가족 여행에 유아 시설이 추천된다.
    ///
    /// 나이대도 함께 본다: 60대 이상을 골랐으면 `elderly` 다 — "부모님과"를 고르지 않아도
    /// 본인이 그 나이대일 수 있다.
    /// ⚠️ 휠체어(`mobilities`)는 v1 서버가 받지 않는다. 무장애 필터는 별도 축이다.
    var courseCodes: [String] {
        var codes: [String] = []
        if companions.contains(.children) { codes.append("kids") }
        if companions.contains(.pet) { codes.append("pet") }
        if companions.contains(.parents) || ageGroups.contains(.sixtiesPlus) { codes.append("elderly") }
        if companions.contains(.partner) { codes.append("couple") }
        if companions.contains(.friends) { codes.append("friends") }
        if companions.contains(.alone) { codes.append("solo") }
        return codes
    }
}

/// 지도를 어느 자리에 맞출지. 정류지가 없을 때 지역만으로 카메라를 잡는 데 쓴다.
struct RegionMapCamera: Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    /// 카카오맵 확대 수준 — **클수록 가깝다**(SDK 규약). 단일 도시 10~11, 복수 시군 묶음 8~9.
    var zoomLevel: Int
}

extension TravelRegion {
    /// 이 지역을 화면에 담을 카메라.
    ///
    /// 시군청 좌표가 아니라 **묶음 전체가 들어오는 자리**를 잡았다 — 가평·양평이나 통영·거제·남해처럼
    /// 여러 시군을 묶은 지역은 두 도심 사이를 중심으로 두고 확대를 낮춰야 한쪽만 보이지 않는다.
    /// 포항·안동은 80km 가까이 떨어져 있어 가장 넓게 잡았다.
    ///
    /// ⚠️ **서버에 지역 좌표가 없어서 앱에 표로 둔다** — `/v1/plan-options`는 코드와 문구만 준다
    /// (`TravelRegion` 주석의 "시군구 코드 매핑은 지역 API 스펙이 정해지면" 참고).
    /// 지역 API가 생기면 이 표를 지우고 서버 값으로 옮긴다.
    var mapCamera: RegionMapCamera {
        switch self {
        case .gapyeongYangpyeong: RegionMapCamera(latitude: 37.661, longitude: 127.499, zoomLevel: 9)
        case .gangneungSokcho: RegionMapCamera(latitude: 37.979, longitude: 128.734, zoomLevel: 9)
        case .gyeongju: RegionMapCamera(latitude: 35.856, longitude: 129.225, zoomLevel: 10)
        case .busan: RegionMapCamera(latitude: 35.180, longitude: 129.076, zoomLevel: 10)
        case .yeosu: RegionMapCamera(latitude: 34.760, longitude: 127.662, zoomLevel: 11)
        case .incheon: RegionMapCamera(latitude: 37.456, longitude: 126.705, zoomLevel: 10)
        case .jeonju: RegionMapCamera(latitude: 35.824, longitude: 127.148, zoomLevel: 11)
        case .jeju: RegionMapCamera(latitude: 33.386, longitude: 126.542, zoomLevel: 9)
        case .chuncheonHongcheon: RegionMapCamera(latitude: 37.789, longitude: 127.810, zoomLevel: 9)
        case .taean: RegionMapCamera(latitude: 36.746, longitude: 126.298, zoomLevel: 10)
        case .tongyeongGeojeNamhae: RegionMapCamera(latitude: 34.857, longitude: 128.316, zoomLevel: 9)
        case .pohangAndong: RegionMapCamera(latitude: 36.294, longitude: 129.036, zoomLevel: 8)
        }
    }
}

// MARK: - 공동 편집

/// 플랜에서의 역할(서버 "플랜 공동 편집"). 소유자만 초대·회수·강퇴·삭제를 할 수 있다.
/// rawValue 는 서버 키다 — 앱이 모르는 값이 오면 매핑에서 버린다(칩만 안 그린다).
enum PlanRole: String, Codable, Sendable, Hashable {
    case owner, editor
}

/// 함께 편집하는 멤버 한 명(`GET /v1/plans/:id` 의 `members[]`).
///
/// `uuid` 는 **멤버 식별자**다(플랜 id 가 아니다) — 강퇴·나가기(`DELETE …/members/:uuid`)에 쓴다.
struct PlanMember: Identifiable, Hashable, Sendable, Codable {
    let uuid: String
    var nickname: String
    var role: PlanRole

    var id: String { uuid }
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

    /// 새 플랜 플로우 4/6 에서 고른 선호 테마 코드. 표시 문구는 서버(`/v1/plan-options`)가 준다 —
    /// 앱에 하드코딩하면 문구 하나 고치는 데 앱 재배포가 필요하다.
    ///  ⚠️ enum 이 아니라 문자열인 이유: 서버가 테마를 하나 추가하면 구 버전 앱의 디코딩이
    ///  통째로 실패한다. 모르는 코드는 칩을 안 그리면 그만이다.
    var themes: [String]
    /// 5/6 예산 — `low`/`medium`/`high`. **nil 은 "고르지 않음"**이고 저예산과 다른 값이다.
    var budget: String?
    /// 4/6 "당일치기만 즐길게요". 날짜로 유추하지 않는다 — 하루짜리 일정과 당일치기 선호는 다르다.
    var dayTripOnly: Bool

    var days: [PlanDay]

    /// 목록 카드가 그릴 만큼의 요약 — 날짜별 **장소 이름만**(`GET /v1/plans`).
    ///
    /// 일정 탭 카드(시안 532:241)가 "DAY 1  황리단길 - 포석정" 처럼 그날 동선을 한 줄로 보여 준다.
    /// `days`는 목록 응답에 없고, 카드마다 상세를 다시 받으면 플랜 개수만큼 왕복이 붙는다.
    ///
    /// ⚠️ **`days`와 같은 것이 아니다.** 상세를 받으면 `days`가 채워지지만 이쪽은 목록에서만 온다.
    /// 항목이 없는 날도 빈 `placeNames`로 들어 있다 — 빼면 DAY 번호가 상세와 어긋난다.
    var daySummaries: [PlanDaySummary]
    /// `coverImageURL`이 없을 때 카드 배경으로 쓸 첫 장소 사진.
    /// 표지를 고르는 화면이 아직 없어 사실상 이쪽이 늘 쓰인다.
    var fallbackImageURL: URL?

    /// 일정으로 **확정한 시각**. `nil` 이면 아직 초안이다.
    ///
    /// "플랜은 초안이고, 일정에 추가하면 확정된다"(2026-08-16 기획 확정) — 이 값 하나가
    /// 플랜 탭과 일정 탭을 가른다. 플랜 탭은 초안을, 일정 탭은 확정된 것을 본다.
    /// 언제 확정했는지까지 담는 이유는 "확정됐다"보다 늘 더 많은 것을 말해 주기 때문이다.
    var confirmedAt: Date?

    var createdAt: Date
    var updatedAt: Date

    // MARK: 공동 편집 (서버 "플랜 공동 편집")

    /// 낙관적 잠금용 버전. 공유 플랜은 저장 때 이 값을 그대로 실어 보내야 하고(없으면
    /// 400 version_required), 그 사이 다른 멤버가 저장했으면 서버가 409 로 최신본을 돌려준다.
    /// **`nil` 은 버전 없는 응답** — 혼자 쓰는 플랜이거나 구버전 서버다(하위 호환으로 그냥 저장된다).
    var version: Int?

    /// 이 플랜에서 내 역할. 소유자만 초대·강퇴·삭제를 할 수 있다.
    /// `nil` 은 역할을 모르는 응답(구버전·목·아직 상세를 안 받음).
    var myRole: PlanRole?

    /// 함께 편집하는 멤버들(소유자 포함). 목록·구버전 응답에는 없어 빈 배열이다.
    var members: [PlanMember]
    /// 정원(소유자 포함). 서버 설정값이라 **앱에 숫자를 적지 않는다** — 실제로 10 에서 6 으로
    /// 바뀐 적이 있다. 목록·구버전 응답에는 없어 `nil` 이고, 그때는 남은 자리를 말하지 않는다.
    var memberCap: Int?
    /// 지금 인원(소유자 포함). 서버가 `members.length` 와 같은 값을 준다 —
    /// 기준이 어긋나면 앱이 한 자리를 더 있는 것으로 표시하고, 링크를 뿌린 사람은
    /// 마지막 한 명이 거절당한 뒤에야 알게 된다.
    var memberCount: Int?

    /// 앞으로 몇 명 더 받을 수 있는지. 정원을 모르는 응답에서는 `nil` 이다.
    var remainingSeats: Int? {
        guard let memberCap else { return nil }
        return max(0, memberCap - (memberCount ?? members.count))
    }

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        region: TravelRegion? = nil,
        party: TravelParty = TravelParty(),
        coverImageURL: URL? = nil,
        themes: [String] = [],
        budget: String? = nil,
        dayTripOnly: Bool = false,
        days: [PlanDay] = [],
        daySummaries: [PlanDaySummary] = [],
        fallbackImageURL: URL? = nil,
        confirmedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        version: Int? = nil,
        myRole: PlanRole? = nil,
        members: [PlanMember] = [],
        memberCap: Int? = nil,
        memberCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.region = region
        self.party = party
        self.coverImageURL = coverImageURL
        self.themes = themes
        self.budget = budget
        self.dayTripOnly = dayTripOnly
        self.days = days
        self.daySummaries = daySummaries
        self.fallbackImageURL = fallbackImageURL
        self.confirmedAt = confirmedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.myRole = myRole
        self.members = members
        self.memberCap = memberCap
        self.memberCount = memberCount
    }
}

extension Plan {
    /// 함께 편집하는 플랜인지 — 나 말고도 멤버가 있다. 목록의 "함께하는 플랜" 구분과 배지에 쓴다.
    var isShared: Bool { members.count > 1 }

    /// 내가 소유자인지. 초대·강퇴·삭제 버튼을 그릴지 가른다.
    /// `myRole` 이 `nil`(역할 미상)이면 소유자로 단정하지 않는다 — 없는 권한을 있는 것처럼 보이면 안 된다.
    var isOwner: Bool { myRole == .owner }

    /// **남이 나를 초대한** 플랜인지 — 목록의 "함께하는 플랜" 배지에 쓴다.
    ///
    /// 목록 응답(`GET /v1/plans`)에는 멤버 수가 없고 `myRole` 만 온다. 편집자면 누군가 나를
    /// 초대했다는 뜻이라 확실히 공유 플랜이다. 소유자 플랜은 혼자 쓰는 것과 공유한 것을
    /// 목록에서 구분할 수 없어(멤버 수를 모른다) 배지를 달지 않는다.
    var isSharedWithMe: Bool { myRole == .editor }
}

/// 목록 카드용 하루 요약. 상세의 `PlanDay`와 달리 **이름만** 들고 있다.
struct PlanDaySummary: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var date: Date
    /// 그날 담긴 장소 이름을 순서대로. 메모만 있는 날은 비어 있다.
    var placeNames: [String]

    init(id: UUID = UUID(), date: Date, placeNames: [String]) {
        self.id = id
        self.date = date
        self.placeNames = placeNames
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

    /// 일정 탭 카드 표기 "2026.08.02 - 2026.08.04"
    var dottedDateRangeText: String {
        "\(PlanDateText.dotted(startDate)) - \(PlanDateText.dotted(endDate))"
    }

    /// 목록 카드 배경으로 쓸 사진 — 표지가 있으면 그것, 없으면 첫 장소 사진.
    ///
    /// **플랜 탭과 일정 탭이 같은 값을 쓰도록 여기 한 곳에 둔다.** 각자 고르게 뒀더니
    /// 한쪽만 폴백을 붙여 같은 플랜이 탭에 따라 사진이 있기도 없기도 했다(2026-08-16).
    /// 표지를 고르는 화면이 아직 없어 실제로는 늘 뒤쪽이 쓰인다.
    ///
    /// 마지막 폴백이 **직접 계산한 첫 장소 사진**인 이유: 서버는 `fallbackImageUrl` 을
    /// **목록 응답에서만** 만들어 준다. 저장(PUT) 응답에는 없어서, 방금 만든 플랜을 목록에
    /// 꽂으면 카드가 빈 채로 뜬다 — 추천 코스로 하루를 가득 채워 만들어도 마찬가지였다
    /// (2026-08-23). 저장 응답에는 `days` 가 실려 오므로 앱이 같은 값을 스스로 고를 수 있다.
    var cardImageURL: URL? { coverImageURL ?? fallbackImageURL ?? firstStopImageURL }

    /// 담긴 장소 중 사진이 있는 첫 곳. 목록 응답은 `days` 가 비어 있어 nil 이고,
    /// 그때는 서버가 준 `fallbackImageURL` 이 이미 같은 값을 들고 있다.
    private var firstStopImageURL: URL? {
        days.lazy.flatMap(\.stops).compactMap(\.place.imageURL).first
    }

    /// 아직 확정하지 않은 초안인지. 플랜 탭이 이걸로 거른다.
    var isDraft: Bool { confirmedAt == nil }

    /// 출발일부터 종료일까지 하루씩 만든 **빈** 날짜들.
    ///
    /// 새 플랜은 `days`가 통째로 비어 있다(`PlanDraft` — 장소는 만든 뒤 상세에서 담는다).
    /// 그 상태에서 "붙일 날이 없다"고 막으면 갓 만든 플랜에는 영영 아무것도 담을 수 없으므로,
    /// 항목을 담을 때 이 목록을 후보로 쓰고 **실제로 담긴 날만** 서버에 생긴다.
    ///
    /// 종료일이 출발일보다 앞서는 값이 들어와도 최소 하루는 돌려준다 — 후보가 0개면
    /// 호출부가 다시 같은 막다른 길에 선다.
    func calendarDays(calendar: Calendar = .current) -> [PlanDay] {
        let start = calendar.startOfDay(for: startDate)
        let span = calendar.dateComponents([.day], from: start,
                                           to: calendar.startOfDay(for: endDate)).day ?? 0
        return (0...max(span, 0)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { PlanDay(date: $0) }
        }
    }

    /// 항목을 담을 수 있는 날 전체 — 여행 기간의 모든 날에 **이미 있는 날을 겹쳐 놓은** 목록.
    ///
    /// 둘 중 하나만 쓰면 안 된다:
    ///  - `days`만 쓰면, 한 번 담고 난 뒤에는 **담긴 날 하나만** 후보로 남아 그 뒤로는 다른 날을
    ///    고를 수 없다(2026-08-16에 실제로 이렇게 새 나갔다 — 메모가 전부 같은 날로 들어갔다).
    ///  - `calendarDays()`만 쓰면 이미 있는 날에도 **새 id**가 붙어 같은 날이 둘로 갈린다.
    ///
    /// 여행 기간 밖에 있는 날도 버리지 않는다 — 날짜를 나중에 줄이면 기존 일정이 기간을 벗어나는데,
    /// 후보에서 빠지면 그 날에 담긴 것들이 화면에서 손댈 수 없는 상태가 된다.
    func dayCandidates(calendar: Calendar = .current) -> [PlanDay] {
        let existing = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var result = calendarDays(calendar: calendar).map {
            existing[calendar.startOfDay(for: $0.date)] ?? $0
        }
        let covered = Set(result.map { calendar.startOfDay(for: $0.date) })
        result += days.filter { !covered.contains(calendar.startOfDay(for: $0.date)) }
        return result.sorted { $0.date < $1.date }
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

    /// "2026.08.02" — 일정 탭 카드의 날짜 표기(시안 532:241).
    ///
    /// ⚠️ 플랜 탭 시안(391:232)도 이 형식인데 앱은 아직 `monthDay`("8월 2일")로 그린다.
    /// 두 탭을 한꺼번에 바꾸는 것은 별도 확인 사항이라 일정 탭에만 쓴다.
    static func dotted(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
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

    /// 같은 날인지. **id 로 비교할 수 없는 자리**에 쓴다 — `Plan.dayCandidates()` 가 만든
    /// 후보는 새로 지어낸 id 를 갖고 있어, 서버에서 받아 온 같은 날과 id 가 다르다.
    /// 그때 id 로 맞추면 이미 있는 날을 못 찾아 같은 날이 하나 더 생긴다.
    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: other)
    }

    /// 번호 뱃지는 장소에만 붙는다 — 메모는 번호를 건너뛴다.
    var stops: [PlanStop] {
        items.compactMap { if case .stop(let stop) = $0 { stop } else { nil } }
    }

    /// `index` 바로 앞의 장소. 사이에 메모가 몇 개 끼어 있어도 건너뛰고 찾는다 —
    /// 이동 거리는 장소와 장소 사이의 값이라 메모가 구간을 끊으면 안 된다.
    func stopBefore(_ index: Int) -> PlanStop? {
        guard index > 0 else { return nil }
        for item in items[..<index].reversed() {
            if case .stop(let stop) = item { return stop }
        }
        return nil
    }

    /// `index` 바로 뒤의 장소. 사이의 메모는 건너뛴다 — 거리는 장소끼리의 값이다.
    func stopAfter(_ index: Int) -> PlanStop? {
        guard items.indices.contains(index) else { return nil }
        for item in items[(index + 1)...] {
            if case .stop(let stop) = item { return stop }
        }
        return nil
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

    /// "DAY 1 · 7/26 목". 상세의 날짜 헤더와 담기 화면(어느 날에 들어가는지 되짚는 줄)이
    /// 같은 표기를 쓰도록 여기 한 곳에 둔다. 번호는 여행 기간에서의 자리라 날짜만으로 알 수 없다.
    func title(number: Int) -> String { "DAY \(number) · \(headerText)" }
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

    init(id: UUID = UUID(), place: PlanPlace) {
        self.id = id
        self.place = place
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

    /// 이 장소가 무장애 조사를 받았는지(`GET /v1/plans/:id` 의 `place.hasAccessInfo`).
    ///
    /// 서버가 `contentID` 로 매번 도출하므로 저장 요청에는 싣지 않는다(보내도 무시된다).
    /// 추천 코스가 소도시 식사·카페 자리를 채우려고 미조사 음식점까지 넣기 때문에 생긴 필드다.
    ///
    /// ⚠️ **`false` 는 "접근 불가"가 아니라 "모른다"** — 관광공사가 아직 조사하지 않은 곳이다.
    /// 조사되면 서버가 자동으로 `true` 로 바꿔 준다. `nil` 은 이 필드를 모르는 응답(구버전·목·나만의 장소).
    var hasAccessInfo: Bool? = nil

    /// 목록에 없어 사용자가 직접 추가한 "나만의 장소". 상세 화면의 두 가지 표현이 모두 여기서 갈린다 —
    /// 번호 뱃지가 라임(딥그린 대신)으로 뜨고, 리뷰 버튼이 사라진다.
    var isCustom: Bool { contentID == nil }

    /// 무장애 정보가 없다고 **명시적으로** 밝혀야 하는 경우.
    /// nil(모르는 응답)이나 나만의 장소는 아니다 — 서버가 false 로 준 조사 미완료만.
    var isUnsurveyed: Bool { hasAccessInfo == false && !isCustom }

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

    /// 두 장소의 **직선** 거리(하버사인). 좌표가 없는 장소가 끼면 구간 자체를 만들지 않는다.
    ///
    /// 실제 이동 거리가 아니라 최단 직선이다 — 경로 API 없이 정직하게 낼 수 있는 값이 이것뿐이라
    /// 화면에도 수단·소요시간을 적지 않는다. 저장하지 않고 매번 계산하는 이유는, 장소 순서를
    /// 바꾸면 모든 구간이 무효가 되는데 저장해 두면 그 갱신을 어딘가에서 빠뜨리기 때문이다.
    static func straightLine(from: PlanPlace, to: PlanPlace) -> TravelLeg? {
        guard let lat1 = from.latitude, let lon1 = from.longitude,
              let lat2 = to.latitude, let lon2 = to.longitude else { return nil }

        let earthRadius = 6_371_000.0
        let toRad = Double.pi / 180
        let dLat = (lat2 - lat1) * toRad
        let dLon = (lon2 - lon1) * toRad
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRad) * cos(lat2 * toRad) * sin(dLon / 2) * sin(dLon / 2)
        let meters = 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
        return TravelLeg(meters: Int(meters.rounded()))
    }

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
