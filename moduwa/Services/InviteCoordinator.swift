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

    /// 링크에서 초대 코드를 뽑는다. 두 형태를 받는다:
    /// - 유니버설 링크: `https://moduwa.app/i/WKQ3M8DZ` (앱 밖에서 탭할 때)
    /// - 커스텀 스킴: `moduwa://i/WKQ3M8DZ` (카톡 등 인앱 웹뷰의 대체 페이지 "앱에서 열기" 버튼)
    ///
    /// 커스텀 스킴은 유니버설 링크와 달리 인앱 브라우저에서도 앱을 여는데, 그 대신 iOS 가
    /// AASA 검증을 하지 않으므로 웹뷰 폴백 전용으로만 쓴다. 둘 다 `/i/{코드}` 규칙은 같다.
    static func code(from url: URL) -> String? {
        // 유니버설 링크: host 가 moduwa.app, path 가 /i/CODE
        if url.host?.contains("moduwa.app") == true {
            return code(fromTokens: url.pathComponents)
        }
        // 커스텀 스킴: moduwa://i/CODE — host 가 "i", path 가 "/CODE" 로 갈리므로 합쳐서 읽는다.
        if url.scheme == "moduwa" {
            var tokens = url.pathComponents
            if let host = url.host { tokens.insert(host, at: 0) }
            return code(fromTokens: tokens)
        }
        return nil
    }

    /// `["i", "CODE"]` 처럼 갈린 조각에서 코드를 꺼낸다. 앞 조각이 `i` 여야 초대 링크다.
    private static func code(fromTokens tokens: [String]) -> String? {
        let parts = tokens.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 2, parts[0] == "i" else { return nil }
        let code = parts[1].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }
}

extension EnvironmentValues {
    @Entry var inviteCoordinator = InviteCoordinator()
}
