import SwiftUI

/// 탭 헤더 오른쪽의 메뉴(햄버거) — 설정(마이페이지)으로 가는 문.
///
/// 네 탭이 같은 자리에 같은 글리프를 두고 있었는데 눌러도 아무 일이 없었다(준비 중 안내).
/// 로그인이 들어오면서 그 자리에 갈 곳이 생겼다 — 로그인·로그아웃·이메일 인증은 특정 탭의
/// 기능이 아니라 앱 전체의 것이므로, 어느 탭에서든 같은 자리에서 닿아야 한다.
///
/// **목적지를 이 버튼이 직접 민다.** 새 시안(977:662)의 설정은 탭바가 남은 전체 화면이라
/// 탭 안에서 밀어 올려야 하는데, 이 버튼이 네 탭의 `NavigationStack` 안에 있으므로 여기에
/// 목적지를 붙이면 네 탭이 각자의 스택에서 같은 화면을 민다 — 탭마다 따로 손볼 것이 없다.
/// (예전 판은 오른쪽에서 나오는 서랍이라 `RootView` 가 탭바 위에 그려야 했다.)
struct AccountMenuButton: View {
    @Environment(SessionStore.self) private var session

    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            Image("hamburger")
                .renderingMode(.template)
                .resizable()
                .frame(width: 25, height: 25)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.account == nil ? "메뉴, 로그인" : "메뉴, 설정")
        .navigationDestination(isPresented: $isPresented) {
            AccountSettingsView()
        }
    }
}
