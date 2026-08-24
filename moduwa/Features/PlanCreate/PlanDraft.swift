import Foundation

/// 새 플랜 플로우가 6단계에 걸쳐 채우는 값.
///
/// `Plan`을 그대로 들고 다니지 않는 이유는 **날짜를 아직 고르지 않은 상태**를 표현해야 하기
/// 때문이다 — `Plan.startDate`는 옵셔널이 아니라 "오늘"과 "고르지 않음"이 같은 값이 된다.
/// 3/6은 건너뛸 수 있는 단계라 그 둘을 구분해야 한다.
struct PlanDraft {
    /// 저장 **전에** 정해 둔다. 서버는 생성·수정이 같은 PUT이라 id를 클라이언트가 만드는데,
    /// 저장할 때마다 새로 만들면 "다시 시도"가 매번 새 플랜을 하나씩 더 남긴다.
    let id = UUID()

    /// 1/6 — 연령·목적·이동 세 축 모두 다중 선택
    var party = TravelParty()
    /// 2/6 — 단일 선택
    var region: TravelRegion?
    /// 3/6 — 둘 다 nil이면 건너뛴 것이다
    var startDate: Date?
    var endDate: Date?
    /// 4/6 — 서버가 준 테마 `code` 목록
    var themes: [String] = []
    /// 5/6 — `low`/`medium`/`high`. nil은 "고르지 않음"이고 저예산과 다르다.
    var budget: String?
}

extension PlanDraft {
    /// 사용자가 고른 목적 중 제목에 쓸 하나.
    ///
    /// 여러 개를 골랐으면 enum 선언 순서(혼자 → 연인 → 친구 …)로 첫 하나만 쓴다.
    /// `Set`을 그대로 순회하면 같은 선택인데도 앱을 다시 켤 때마다 제목이 달라진다.
    private var titleCompanion: CompanionType? {
        CompanionType.allCases.first(where: party.companions.contains)
    }

    /// "타겟 + 여행지"로 제목을 짓는다 — "아이와 함께하는 경주 여행".
    ///
    /// 목적·지역은 둘 다 건너뛸 수 있으므로 네 경우가 모두 자연스러워야 한다.
    /// "혼자"만 서술을 바꾼다 — "혼자 함께하는"은 말이 되지 않는다.
    /// 사용자는 상세에서 제목을 고칠 수 있으니 완벽한 작명일 필요는 없고, **비어 있지만 않으면 된다**.
    var generatedTitle: String {
        let target = titleCompanion.map { $0 == .alone ? "혼자 떠나는" : "\($0.label) 함께하는" }
        return switch (target, region?.label) {
        case (let target?, let place?): "\(target) \(place) 여행"
        case (let target?, nil): "\(target) 여행"
        case (nil, let place?): "\(place) 여행"
        case (nil, nil): "나의 여행"
        }
    }

    /// 서버에 보낼 플랜.
    ///
    /// ⚠️ `days`는 **빈 배열**이다 — 장소는 만들고 난 뒤 상세에서 담는다.
    func makePlan(calendar: Calendar = .current) -> Plan {
        // 3/6을 건너뛰면 날짜가 없는데 서버 스키마에는 필수다. 오늘 하루로 채운다 —
        // 임의의 먼 미래보다 "오늘"이 아직 정하지 않았다는 걸 알아채기 쉽고,
        // 지난 여행으로 접히지도 않는다(`Plan.isPast()`는 종료일이 오늘보다 이전일 때만 참이다).
        let start = startDate ?? calendar.startOfDay(for: .now)
        let end = endDate ?? start

        return Plan(
            id: id,
            title: generatedTitle,
            startDate: start,
            endDate: end,
            region: region,
            party: party,
            themes: themes,
            budget: budget,
            days: []
        )
    }
}

// MARK: - 단계

/// 6단계. rawValue가 그대로 진행 표시의 "n / 6"이다.
enum PlanCreateStep: Int, CaseIterable, Identifiable {
    case party = 1, region, dates, themes, budget, finish

    var id: Int { rawValue }

    static let total = PlanCreateStep.allCases.count

    /// 화면 제목이자 스크린리더가 단계 이동 때 읽어 주는 문장.
    var question: String {
        switch self {
        case .party: "누구와 여행하세요? (본인 포함)"
        case .region: "어디로 떠날 계획이신가요?"
        case .dates: "언제 여행하시나요?"
        case .themes: "선호하는 테마를 선택해 주세요"
        case .budget: "예산은 어떻게 생각 중이신가요?"
        case .finish: "거의 다 됐어요!\n모두와 추천 코스를 보러 갈까요?"
        }
    }
}
