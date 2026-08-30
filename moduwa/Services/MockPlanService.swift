import Foundation

/// 프리뷰·오프라인 개발용 PlanService. **실행 중인 앱에는 주입되지 않는다** —
/// `moduwaApp`이 `APIPlanService`로 덮어쓴다(`@Entry` 기본값은 프리뷰가 죽지 않게 두는 것이다).
///
/// 목 데이터가 화면에 흘러들어가면 사용자는 자기가 만든 적 없는 여행을 자기 플랜으로 읽게 된다.
/// 그래서 `MockData.plans`는 이 타입과 `#Preview` 밖으로 나가지 않는다.
///
/// 저장을 실제로 반영하는 이유: 프리뷰에서 편집→완료를 눌렀을 때 아무것도 바뀌지 않으면
/// 화면이 고장 난 것인지 서비스가 목인지 구분되지 않는다.
actor MockPlanService: PlanService {
    private var plans: [Plan]

    init(plans: [Plan] = MockData.plans) {
        self.plans = plans
    }

    /// 서버와 같이 **`days`를 뺀다** — 목록에서 일정이 딸려 오면 상세가 로딩을 건너뛰게 되고,
    /// 라이브 서버에서만 빈 화면이 되는 차이가 프리뷰에서는 드러나지 않는다.
    func fetchPlans() async throws -> [Plan] {
        plans.map { plan in
            var summary = plan
            summary.days = []
            return summary
        }
    }

    func fetchPlan(id: UUID) async throws -> Plan {
        guard let plan = plans.first(where: { $0.id == id }) else { throw PlanServiceError.notFound }
        return plan
    }

    @discardableResult
    func savePlan(_ plan: Plan, authorNm: String?) async throws -> Plan {
        var saved = plan
        saved.updatedAt = .now
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = saved
        } else {
            plans.append(saved)
        }
        return saved
    }

    func deletePlan(id: UUID) async throws {
        guard let index = plans.firstIndex(where: { $0.id == id }) else {
            throw PlanServiceError.notFound
        }
        plans.remove(at: index)
    }

    @discardableResult
    func setPlanConfirmed(id: UUID, _ confirmed: Bool) async throws -> Plan {
        guard let index = plans.firstIndex(where: { $0.id == id }) else {
            throw PlanServiceError.notFound
        }
        // 서버와 같이 처음 확정한 시각을 지킨다 — 다시 눌러도 밀리지 않는다.
        plans[index].confirmedAt = confirmed ? (plans[index].confirmedAt ?? .now) : nil
        return plans[index]
    }

    func recommendCourse(_ request: CourseRequest) async throws -> RecommendedCourse {
        RecommendedCourse(regionLabel: "강릉", stay: nil, days: [], notes: [])
    }

    func createInvite(planId: UUID) async throws -> PlanInvite {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        return PlanInvite(
            code: code,
            inviteURL: URL(string: "https://moduwa.app/i/\(code)")!,
            expiresAt: Date().addingTimeInterval(30 * 60),
            expiresInMinutes: 30
        )
    }

    func revokeInvite(planId: UUID) async throws {}

    func acceptInvite(code: String) async throws -> InviteAcceptance {
        let plan = plans.first
        return InviteAcceptance(
            planId: plan?.id ?? UUID(),
            title: plan?.title ?? "여행 플랜",
            myRole: .editor,
            alreadyMember: false
        )
    }

    func removeMember(planId: UUID, memberUUID: String) async throws {
        guard let index = plans.firstIndex(where: { $0.id == planId }) else {
            throw PlanServiceError.notFound
        }
        plans[index].members.removeAll { $0.uuid == memberUUID }
    }

    func fetchPlanOptions() async throws -> PlanOptions { Self.sampleOptions }

    /// 프리뷰에서 4/6·5/6이 빈 화면으로 보이지 않게 두는 사본.
    /// **실제 앱에는 절대 흘러가지 않는다** — 이 타입 자체가 프리뷰 전용이다(위 주석 참고).
    /// 서버가 문구를 고치면 여기가 낡는데, 그래도 되는 이유가 그것이다.
    static let sampleOptions = PlanOptions(
        themes: [
            PlanOption(code: "camping", label: "차박·캠핑", hint: nil),
            PlanOption(code: "waterpark", label: "워터파크", hint: nil),
            PlanOption(code: "photo", label: "SNS 사진", hint: nil),
            PlanOption(code: "nature", label: "자연과 함께", hint: nil),
            PlanOption(code: "indoor", label: "실내", hint: nil),
            PlanOption(code: "heritage", label: "전통과 역사", hint: nil),
            PlanOption(code: "scenery", label: "아름다운 풍경", hint: nil),
            PlanOption(code: "shopping", label: "쇼핑하기", hint: nil),
            PlanOption(code: "culture", label: "문화·예술", hint: nil),
            PlanOption(code: "art", label: "미술", hint: nil),
            PlanOption(code: "food", label: "먹방 투어", hint: nil),
            PlanOption(code: "nightview", label: "야경이 예쁜 곳", hint: nil),
        ],
        budgets: [
            PlanOption(code: "low", label: "저예산", hint: "아끼고 싶어요"),
            PlanOption(code: "medium", label: "중예산", hint: "부담스럽지 않게 쓰고 싶어요"),
            PlanOption(code: "high", label: "고예산", hint: "여유 있게 즐길래요"),
        ]
    )
}

/// 프리뷰 전용 — 플랜이 0건인 기기. 서버가 비어 있는 지금 실제 앱이 보게 되는 상태다.
struct EmptyPlanService: PlanService {
    func recommendCourse(_ request: CourseRequest) async throws -> RecommendedCourse {
        RecommendedCourse(regionLabel: "", stay: nil, days: [], notes: [])
    }

    func fetchPlans() async throws -> [Plan] { [] }

    func fetchPlan(id: UUID) async throws -> Plan { throw PlanServiceError.notFound }

    @discardableResult
    func savePlan(_ plan: Plan, authorNm: String?) async throws -> Plan {
        throw PlanServiceError.unavailable
    }

    func deletePlan(id: UUID) async throws { throw PlanServiceError.notFound }

    @discardableResult
    func setPlanConfirmed(id: UUID, _ confirmed: Bool) async throws -> Plan {
        throw PlanServiceError.notFound
    }

    func createInvite(planId: UUID) async throws -> PlanInvite { throw PlanServiceError.unavailable }
    func revokeInvite(planId: UUID) async throws { throw PlanServiceError.unavailable }
    func acceptInvite(code: String) async throws -> InviteAcceptance { throw PlanServiceError.invalidCode }
    func removeMember(planId: UUID, memberUUID: String) async throws { throw PlanServiceError.notFound }

    func fetchPlanOptions() async throws -> PlanOptions { MockPlanService.sampleOptions }
}

/// 프리뷰 전용 — 목록·상세가 모두 실패하는 기기 (오류 화면 확인용).
struct FailingPlanService: PlanService {
    func recommendCourse(_ request: CourseRequest) async throws -> RecommendedCourse {
        throw PlanServiceError.notFound
    }

    func fetchPlans() async throws -> [Plan] { throw PlanServiceError.unavailable }

    func fetchPlan(id: UUID) async throws -> Plan { throw PlanServiceError.unavailable }

    @discardableResult
    func savePlan(_ plan: Plan, authorNm: String?) async throws -> Plan {
        throw PlanServiceError.server(message: "일정을 저장하지 못했어요. (서버 점검 중)")
    }

    func deletePlan(id: UUID) async throws {
        throw PlanServiceError.server(message: "플랜을 삭제하지 못했어요. (서버 점검 중)")
    }

    @discardableResult
    func setPlanConfirmed(id: UUID, _ confirmed: Bool) async throws -> Plan {
        throw PlanServiceError.server(message: "일정에 추가하지 못했어요. (서버 점검 중)")
    }

    func createInvite(planId: UUID) async throws -> PlanInvite {
        throw PlanServiceError.server(message: "초대 링크를 만들지 못했어요. (서버 점검 중)")
    }
    func revokeInvite(planId: UUID) async throws {
        throw PlanServiceError.server(message: "초대를 회수하지 못했어요. (서버 점검 중)")
    }
    func acceptInvite(code: String) async throws -> InviteAcceptance {
        throw PlanServiceError.server(message: "초대를 수락하지 못했어요. (서버 점검 중)")
    }
    func removeMember(planId: UUID, memberUUID: String) async throws {
        throw PlanServiceError.server(message: "멤버를 정리하지 못했어요. (서버 점검 중)")
    }

    /// 선택지를 못 받으면 새 플랜 플로우가 4/6·5/6을 건너뛴다 — 그 동작을 프리뷰로 볼 수 있게 던진다.
    func fetchPlanOptions() async throws -> PlanOptions { throw PlanServiceError.unavailable }
}
