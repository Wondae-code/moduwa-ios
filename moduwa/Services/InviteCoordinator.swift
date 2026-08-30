import SwiftUI

/// 초대 수락을 앱 전체가 공유하는 우편함(서버 "플랜 공동 편집").
///
/// 유니버설 링크는 앱 어디서든(`RootView`) 도착하지만, 실제 수락과 목록 갱신은 플랜 탭
/// (`PlanView`)이 한다 — 거기에 `planService` 와 목록 상태가 있다. 그 사이를 잇는 값 하나만
/// 여기 둔다. 코드 수동 입력 폴백도 같은 길을 쓴다.
///
/// `@MainActor` 를 붙이지 않는다 — `EnvironmentValues` 기본값이 액터 바깥에서 만들어지기
/// 때문이다(`AccountDrawerPresenter` 와 같은 판단). 읽고 쓰는 곳은 모두 뷰(메인 액터)다.
@Observable
final class InviteCoordinator {
    /// 아직 수락하지 않은 초대 코드. 로그인하지 않았으면 로그인한 뒤 이어서 수락한다.
    var pendingCode: String?
    /// 수락 결과 안내(성공·이미참여·실패). `PlanView` 가 알림으로 띄우고 비운다.
    var notice: String?

    /// 유니버설 링크에서 코드를 뽑는다 — `https://moduwa.app/i/WKQ3M8DZ` → `WKQ3M8DZ`.
    /// `moduwa.app` 의 `/i/{코드}` 형태일 때만 받는다(다른 링크는 무시).
    static func code(from url: URL) -> String? {
        guard url.host?.contains("moduwa.app") == true else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "i" else { return nil }
        let code = parts[1].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }
}

extension EnvironmentValues {
    @Entry var inviteCoordinator = InviteCoordinator()
}
