import Foundation

/// 후기 신고 사유. rawValue 는 서버로 보내는 안정 키이고 표시 문구는 `label` 이다
/// (`AccessibilityFeature`·`PlanRole` 과 같은 규칙).
///
/// 목록은 앱이 쥔다 — 서버가 사유를 늘리면 구 버전 앱이 모르는 값을 그릴 수 없고, 신고 사유는
/// 문구가 자주 바뀌는 종류의 사전이 아니다.
enum ReviewReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam
    case abuse
    case falseInfo
    case privacyLeak
    case irrelevant
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "스팸·광고예요"
        case .abuse: "욕설·혐오 표현이 있어요"
        case .falseInfo: "사실과 달라요"
        case .privacyLeak: "개인정보가 드러나 있어요"
        case .irrelevant: "이 장소와 관련이 없어요"
        case .other: "그 외"
        }
    }
}
