import SwiftUI

/// 플랜 조회·저장 실패 사유 중 **사용자에게 그대로 보여 줄 수 있는** 것들.
/// (URLError 등 시스템 오류는 이 타입으로 감싸지 않고 호출부에서 일반 문구로 처리한다 — `FeedServiceError`와 같은 규칙)
enum PlanServiceError: LocalizedError {
    /// 이 데이터 소스로는 서버 저장을 할 수 없음 (API 키 미설정, 목 구현 등)
    case unavailable
    /// 서버가 준 한국어 사유 (`{error, message}`)
    case server(message: String)
    /// 404 — 없는 플랜이거나 다른 기기의 플랜이라 조회 자체가 막힌 경우
    case notFound
    /// 403 — 다른 기기가 만든 플랜을 덮어쓰려 한 경우
    case forbidden
    /// 이 기기의 첫 저장이라 서버가 표시 이름을 요구함. 호출부가 이름을 정해 다시 시도한다.
    case nicknameRequired

    var errorDescription: String? {
        switch self {
        case .unavailable: "지금은 플랜을 저장할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .server(let message): message
        case .notFound: "플랜을 찾을 수 없어요. 목록에서 지워졌을 수 있어요."
        case .forbidden: "다른 기기에서 만든 플랜이라 수정할 수 없어요."
        case .nicknameRequired: "플랜에 표시될 이름을 입력해 주세요."
        }
    }
}

/// 플랜 데이터 소스 (`/v1/plans`).
///
/// 플랜의 소유자는 `deviceId` 하나로 정해진다. 이 값은 **구현체가 들고 있고** 호출부는 넘기지 않는다 —
/// 화면마다 기기 키를 챙기게 하면 언젠가 한 곳이 다른 값을 쓰게 되고, 그러면 같은 기기의 플랜이
/// 두 주인으로 갈린다. 어느 값을 쓰는지는 `APIPlanService`가 한 곳에서 정한다.
protocol PlanService: Sendable {
    /// 내 플랜 목록.
    ///
    /// ⚠️ 반환된 `Plan`의 **`days`는 비어 있다** — 서버가 목록 응답에 일정 본문을 싣지 않는다
    /// (목록 카드가 제목·날짜·표지만 쓴다). 일정이 필요하면 `fetchPlan(id:)`으로 상세를 따로 받아야 한다.
    func fetchPlans() async throws -> [Plan]

    /// 플랜 상세 — 목록과 같은 필드에 `days`가 채워져 온다.
    func fetchPlan(id: UUID) async throws -> Plan

    /// 플랜 저장. 서버는 **생성과 수정이 같은 요청**(PUT)이라 여기서도 하나로 둔다.
    ///
    /// ⚠️ 본문(`days`)은 통째로 교체된다. 그래서 **상세를 받아 온 플랜**으로만 불러야 한다 —
    /// 목록에서 온 플랜(`days`가 빈 배열)을 그대로 넘기면 서버의 일정이 지워진다.
    /// - Parameter authorNm: 사용자가 **직접 정한** 표시 이름만 넘긴다. 정하지 않았으면 `nil`.
    ///   ⚠️ 지어낸 기본 이름을 넣지 말 것 — 서버는 받은 이름으로 이 기기의 닉네임을 갱신하므로
    ///   후기에서 정해 둔 실제 닉네임을 덮어쓴다(`FeedService.submitReviewComment`의 같은 주의사항 참고).
    ///   `nil`이면 서버가 기존 닉네임을 재사용하고, 정말 첫 저장이면 `.nicknameRequired`를 던진다.
    /// - Returns: 서버에 저장된 플랜(상세와 같은 형태). `updatedAt`이 갱신돼 있으므로 화면은 이 값을 쓴다.
    @discardableResult
    func savePlan(_ plan: Plan, authorNm: String?) async throws -> Plan

    /// 플랜 삭제 (`DELETE /v1/plans/:id`).
    ///
    /// ⚠️ **되돌릴 수 없다** — 서버에 휴지통이 없고 일정도 함께 지워진다.
    /// 호출부는 반드시 확인을 한 번 받고 부른다.
    /// 이미 없는 플랜이면 `.notFound`를 던진다 — 목록이 낡았다는 뜻이라 다시 받아야 한다.
    func deletePlan(id: UUID) async throws

    /// 새 플랜 플로우 4/6·5/6의 선택지 (`GET /v1/plan-options`).
    ///
    /// 플랜 조회와 달리 **기기와 무관한 공용 사전**이라 `deviceId`를 싣지 않는다.
    /// 실패하면 그 두 단계를 그릴 수 없다 — 호출부가 건너뛴다(문구를 앱에서 지어낼 수 없다).
    func fetchPlanOptions() async throws -> PlanOptions
}

extension EnvironmentValues {
    @Entry var planService: any PlanService = MockPlanService()
}
