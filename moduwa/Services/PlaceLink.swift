import SwiftUI

/// 장소를 가리키는 우리 링크 — `https://moduwa.app/p/{contentId}`.
///
/// **카카오맵 링크 대신 이것을 보낸다.** 카카오맵 화면에는 무장애 정보가 없어서, 링크를 받은
/// 사람이 우리가 보여 주려던 것을 못 본다. 이 링크는 앱이 깔려 있으면 그 장소 상세로 곧장
/// 열리고, 없으면 서버의 안내 페이지로 간다.
///
/// ⚠️ **호스트는 엔타이틀먼트(`applinks:moduwa.app`)와 같아야 한다.** 다르면 iOS 가
/// 유니버설 링크로 취급하지 않고 사파리가 열린다.
///
/// ⚠️ 서버의 AASA 가 `/p/*` 를 포함해야 앱이 열린다(2026-09-05 현재 `/i/*` 만 있다 —
/// `docs/BACKEND_REQUEST_place-links.md`). 그 전까지 이 링크는 웹 페이지로만 간다.
enum PlaceLink {
    static let host = "moduwa.app"

    /// 공유용 주소. **관광공사 contentId 가 아닌 것에는 만들지 않는다** —
    /// 번들·목 데이터의 `mock-1` 같은 id 로 링크를 만들면 아무 데도 닿지 않는다.
    static func url(contentId: String) -> URL? {
        guard !contentId.isEmpty, contentId.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://\(host)/p/\(contentId)")
    }

    /// 링크에서 contentId 를 뽑는다. 초대 링크와 같은 두 형태를 받는다
    /// (`InviteCoordinator.code(from:)` 와 같은 규칙 — 커스텀 스킴은 인앱 웹뷰 폴백용이다).
    static func contentId(from url: URL) -> String? {
        if url.host?.contains(host) == true {
            return contentId(fromTokens: url.pathComponents)
        }
        if url.scheme == "moduwa" {
            var tokens = url.pathComponents
            if let host = url.host { tokens.insert(host, at: 0) }
            return contentId(fromTokens: tokens)
        }
        return nil
    }

    private static func contentId(fromTokens tokens: [String]) -> String? {
        let parts = tokens.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 2, parts[0] == "p" else { return nil }
        // 링크로 들어온 값은 그대로 믿지 않는다 — 숫자만 통과시킨다.
        let id = parts[1]
        return id.allSatisfy(\.isNumber) && !id.isEmpty ? id : nil
    }
}

/// 링크로 도착한 장소를 홈 탭까지 옮기는 우편함.
///
/// 링크는 앱 어디서든(`RootView`) 도착하지만 장소 상세를 미는 것은 홈 탭이다 —
/// 그 사이를 잇는 값 하나만 둔다(`InviteCoordinator` 와 같은 구조).
@Observable
final class PlaceLinkRouter {
    /// 아직 열지 않은 장소의 contentId.
    var pendingContentId: String?
    /// 열지 못했을 때의 안내. 홈이 알림으로 띄우고 비운다.
    var notice: String?
}

extension EnvironmentValues {
    @Entry var placeLinkRouter = PlaceLinkRouter()
}
