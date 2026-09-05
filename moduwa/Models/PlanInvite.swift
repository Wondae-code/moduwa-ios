import Foundation

/// 초대 링크 발급 결과 (`POST /v1/plans/:planId/invites`, 소유자 전용).
///
/// 플랜당 활성 코드는 **하나**다 — 재발급하면 서버가 이전 링크를 자동 회수한다. 그래서 앱에는
/// "링크 끄기" 같은 별도 UI가 필요 없고, 회수는 명시적 회수(`revokeInvite`)만 있으면 된다.
/// 코드는 **소비되지 않는다** — 단톡방에 링크 하나를 뿌려 여럿이 들어오는 게 정상이다.
/// 통제 장치는 만료(30분)·회수·정원이다(정원은 서버 설정값 — 앱에 숫자를 적지 않는다).
struct PlanInvite: Sendable, Hashable {
    /// 수동 입력 폴백용 코드(예: `WKQ3M8DZ`). 서버는 하이픈·소문자가 섞여도 받아 준다.
    let code: String
    /// 공유 시트로 내보낼 유니버설 링크(`https://moduwa.app/i/WKQ3M8DZ`).
    let inviteURL: URL
    let expiresAt: Date
    /// 서버가 계산해 준 남은 분(대개 30). 문구에 그대로 쓴다 — 앱이 시계로 다시 재지 않는다.
    let expiresInMinutes: Int
    /// 지금 인원과 정원(둘 다 소유자 포함). 구버전 응답에는 없어 `nil` 이다.
    ///
    /// **링크를 막 만든 그 순간이 "몇 명 더 받을 수 있는지" 를 알아야 하는 때다** —
    /// 그래서 플랜 상세를 다시 부르지 않고 이 응답으로 바로 띄운다(서버팀 제안).
    var memberCount: Int? = nil
    var memberCap: Int? = nil

    /// 앞으로 몇 명 더 받을 수 있는지. 정원을 모르는 응답에서는 `nil`.
    var remainingSeats: Int? {
        guard let memberCap, let memberCount else { return nil }
        return max(0, memberCap - memberCount)
    }
}

/// 초대 수락 결과 (`POST /v1/plan-invites/accept`).
struct InviteAcceptance: Sendable, Hashable {
    let planId: UUID
    let title: String
    let myRole: PlanRole
    /// 이미 멤버였는지. 같은 링크로 다시 들어온 경우다 — "이미 참여 중이에요"로 안내한다.
    let alreadyMember: Bool
}
