import SwiftUI

/// 탭 헤더 오른쪽의 메뉴(햄버거) — 마이페이지 서랍으로 가는 문.
///
/// 네 탭이 같은 자리에 같은 글리프를 두고 있었는데 눌러도 아무 일이 없었다(준비 중 안내).
/// 로그인이 들어오면서 그 자리에 갈 곳이 생겼다 — 로그인·로그아웃·이메일 인증은 특정 탭의
/// 기능이 아니라 앱 전체의 것이므로, 어느 탭에서든 같은 자리에서 닿아야 한다.
///
/// **여기서 서랍을 그리지 않는다.** 서랍은 탭바까지 덮어야 하는데(시안 821:103) 이 버튼은 탭
/// 안쪽 헤더에 있고, 시트·전체화면으로 띄우면 아래에서 위로 올라온다. 그리는 자리는
/// `RootView` 이고 이 버튼은 열어 달라고만 말한다(`AccountDrawerPresenter`).
struct AccountMenuButton: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.accountDrawer) private var drawer

    var body: some View {
        Button { drawer.open() } label: {
            Image("hamburger")
                .renderingMode(.template)
                .resizable()
                .frame(width: 25, height: 25)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.account == nil ? "메뉴, 로그인" : "메뉴, 마이페이지")
    }
}
