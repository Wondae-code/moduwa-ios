import SwiftUI

/// "새 플랜을 만들고 싶다"는 요청을 앱 전체가 공유하는 자리.
///
/// 홈 히어로 카드의 "추천 여행 코스 보러가기"(시안 13:128 의 라임 CTA)가 눌리면 플랜 생성
/// 6단계 플로우로 가야 한다. 그런데 그 플로우는 **플랜 탭이 쥐고 있다** — 만든 플랜을 목록에
/// 꽂고 상세로 밀어 주는 일(`PlanView.onPlanCreated`)이 거기 있기 때문이다. 홈에서 직접 띄우면
/// 만든 플랜이 어느 목록에도 들어가지 않는다.
///
/// 그래서 홈은 "만들고 싶다"만 말하고, `RootView` 가 플랜 탭으로 옮기고, 플랜 목록이 플로우를
/// 연다. `InviteCoordinator` 와 같은 방식이다.
///
/// `@MainActor` 를 붙이지 않는다 — `EnvironmentValues` 기본값이 액터 바깥에서 만들어진다.
@Observable
final class PlanCreationSignal {
    /// 플로우를 열어 달라는 요청. 여는 쪽이 열고 나서 스스로 내린다.
    var isRequested = false
}

extension EnvironmentValues {
    @Entry var planCreation = PlanCreationSignal()
}
