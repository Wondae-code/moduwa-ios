import Foundation

/// 새 플랜 플로우 4/6(테마)·5/6(예산)의 선택지 한 개.
///
/// **표시 문구를 앱에 두지 않는다** — 서버(`GET /v1/plan-options`)가 `code`와 `label`을 함께 준다.
/// 문구 하나 고치는 데 앱 재배포가 필요해지는 것을 막기 위한 구조이고, 저장되는 값은 `code`뿐이다
/// (`Plan.themes`·`Plan.budget`이 문자열인 이유와 같다).
struct PlanOption: Identifiable, Hashable, Sendable, Decodable {
    let code: String
    let label: String
    /// 예산에만 붙는 부연 — "아끼고 싶어요". 테마에는 없다.
    let hint: String?

    var id: String { code }
}

/// `GET /v1/plan-options` 응답 전체.
struct PlanOptions: Hashable, Sendable, Decodable {
    var themes: [PlanOption]
    var budgets: [PlanOption]

    /// 아직 받지 못한 상태. 비어 있으면 해당 단계를 그릴 수 없다 —
    /// 앱에 하드코딩한 목록으로 대신하면 서버가 모르는 코드를 저장하게 된다.
    static let empty = PlanOptions(themes: [], budgets: [])

    var isEmpty: Bool { themes.isEmpty && budgets.isEmpty }
}
