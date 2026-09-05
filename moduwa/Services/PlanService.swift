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
    /// 401 `login_required` — 플랜은 개인 데이터라 **조회도 로그인 필수**다(백엔드 030).
    case loginRequired
    /// 401 `session_expired` — 토큰이 낡았다. 앱은 로그아웃 상태로 돌아간다.
    case sessionExpired

    /// 409 `version_conflict` — 공유 플랜을 저장하는 사이 다른 멤버가 먼저 저장했다.
    /// `latest` 에 서버가 준 **최신 본문 전체**(days 포함)가 들어 있다 — 다시 GET 하지 않고
    /// 이 값으로 화면을 갈아끼운 뒤 재편집시킨다(서버 "플랜 공동 편집" 규칙).
    case versionConflict(latest: Plan)

    /// 403 `owner_only` — 편집자가 소유자 전용 기능(초대·회수·강퇴·삭제)을 시도했다.
    /// ⚠️ 404 가 아니다 — 플랜은 그대로 있다. 목록에서 지우면 안 된다.
    case ownerOnly

    /// 400 `invalid_code` — 잘못된 초대 코드.
    case invalidCode
    /// 400 `invite_expired` — 만료된 초대(30분). 새 코드를 요청하게 안내한다.
    case inviteExpired
    /// 409 `member_limit` — 정원 초과. **숫자는 서버 문구를 그대로 쓴다** —
    /// 정원은 서버 설정값이라 앱에 적어 두면 바뀔 때마다 거짓말이 된다(10 → 6 으로 바뀐 적 있다).
    case memberLimit(message: String?)
    /// 400 `owner_cannot_leave` — 소유자는 나갈 수 없다(삭제로만 정리된다).
    case ownerCannotLeave

    var errorDescription: String? {
        switch self {
        case .unavailable: "지금은 플랜을 저장할 수 없어요. 잠시 후 다시 시도해 주세요."
        case .server(let message): message
        case .notFound: "플랜을 찾을 수 없어요. 목록에서 지워졌을 수 있어요."
        case .forbidden: "다른 기기에서 만든 플랜이라 수정할 수 없어요."
        case .nicknameRequired: "플랜에 표시될 이름을 입력해 주세요."
        case .loginRequired: "로그인하면 플랜을 만들고 볼 수 있어요."
        case .sessionExpired: "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .versionConflict: "다른 멤버가 방금 수정했어요. 최신 내용으로 맞췄어요. 다시 편집해 주세요."
        case .ownerOnly: "플랜을 만든 사람만 할 수 있어요."
        case .invalidCode: "초대 코드가 올바르지 않아요. 다시 확인해 주세요."
        case .inviteExpired: "초대가 만료됐어요. 초대한 분에게 새 코드를 요청하세요."
        case .memberLimit(let message): message ?? "정원이 가득 찼어요. 더 초대할 수 없어요."
        case .ownerCannotLeave: "플랜을 만든 사람은 나갈 수 없어요. 플랜을 삭제하면 정리돼요."
        }
    }
}

/// 플랜 데이터 소스 (`/v1/plans`).
///
/// 플랜의 소유자는 **로그인한 계정**이다(백엔드 030). 예전에는 기기 키(`deviceId`)가 소유자였는데,
/// 그러면 그 값을 아는 사람이 남의 플랜을 보고 지울 수 있었다. 지금은 세션 토큰이 신원이고
/// 구현체가 요청마다 붙인다 — 호출부는 아무것도 넘기지 않는다.
///
/// ⚠️ **비로그인이면 조회조차 401**(`.loginRequired`)이다. 목록 화면은 그 경우 오류가 아니라
/// "로그인하면 볼 수 있어요"를 그려야 한다.
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

    /// 플랜을 일정으로 확정하거나 초안으로 되돌린다
    /// (`POST`/`DELETE /v1/plans/:planId/confirm`).
    ///
    /// **`savePlan`으로 하지 않는 이유**: 저장은 PUT 으로 본문을 통째로 교체하므로, 상태 한 칸을
    /// 바꾸자고 부르려면 온전한 플랜(`days` 포함)을 먼저 받아 와야 한다. 목록에서 온 플랜을
    /// 실수로 넘기면 서버의 일정이 지워진다. 그 위험을 아예 없애려고 길을 따로 냈다.
    ///
    /// 같은 상태로 다시 불러도 성공한다 — 두 번 눌렀다고 실패를 보여 줄 이유가 없다.
    /// - Returns: 갱신된 플랜(`confirmedAt`이 반영돼 있다). **`days`가 채워져 온다.**
    @discardableResult
    func setPlanConfirmed(id: UUID, _ confirmed: Bool) async throws -> Plan

    /// AI 추천 코스 (`POST /v1/plans/recommend`). **저장하지 않는다** — 제안만 받아 오고,
    /// 사용자가 받아들이면 호출부가 `savePlan(_:authorNm:)` 으로 올린다.
    ///
    /// 로그인 필수다. 그 지역에 후보가 없으면 `.notFound` 를 던진다(`no_candidates`).
    func recommendCourse(_ request: CourseRequest) async throws -> RecommendedCourse

    /// 새 플랜 플로우 4/6·5/6의 선택지 (`GET /v1/plan-options`).
    ///
    /// 플랜 조회와 달리 **누구에게나 같은 공용 사전**이라 로그인이 필요하지 않다.
    /// 실패하면 그 두 단계를 그릴 수 없다 — 호출부가 건너뛴다(문구를 앱에서 지어낼 수 없다).
    func fetchPlanOptions() async throws -> PlanOptions

    // MARK: - 공동 편집 (서버 "플랜 공동 편집")

    /// 초대 링크를 발급한다 (`POST /v1/plans/:planId/invites`, **소유자 전용**).
    /// 재발급하면 서버가 이전 링크를 자동 회수한다 — 플랜당 활성 코드는 하나다.
    /// 편집자가 부르면 `.ownerOnly` 를 던진다.
    func createInvite(planId: UUID) async throws -> PlanInvite

    /// 활성 초대를 회수한다 (`DELETE /v1/plans/:planId/invites`, **소유자 전용**).
    func revokeInvite(planId: UUID) async throws

    /// 초대 코드로 플랜에 참여한다 (`POST /v1/plan-invites/accept`).
    /// 하이픈·소문자가 섞여도 서버가 받아 준다. 만료/오류는 `.inviteExpired`/`.invalidCode`,
    /// 정원 초과는 `.memberLimit`.
    func acceptInvite(code: String) async throws -> InviteAcceptance

    /// 멤버를 내보낸다 (`DELETE /v1/plans/:planId/members/:uuid`).
    /// **소유자가 부르면 강퇴, 본인 uuid 를 넘기면 나가기**다. 소유자가 자기 uuid 로 부르면
    /// 서버가 `.ownerCannotLeave` 를 던진다(삭제로만 정리된다).
    func removeMember(planId: UUID, memberUUID: String) async throws
}

extension EnvironmentValues {
    @Entry var planService: any PlanService = MockPlanService()
}
