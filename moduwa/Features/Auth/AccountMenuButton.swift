import SwiftUI

/// 탭 헤더 오른쪽의 메뉴(햄버거) — 마이페이지 서랍으로 가는 문.
///
/// 네 탭이 같은 자리에 같은 글리프를 두고 있었는데 눌러도 아무 일이 없었다(준비 중 안내).
/// 로그인이 들어오면서 그 자리에 갈 곳이 생겼다 — 로그인·로그아웃·이메일 인증은 특정 탭의
/// 기능이 아니라 앱 전체의 것이므로, 어느 탭에서든 같은 자리에서 닿아야 한다.
///
/// 시트가 아니라 `fullScreenCover` + 투명 배경이다(시안 821:103). 서랍은 화면 오른쪽 295pt 만
/// 덮고 나머지는 어두워진 앱이 그대로 보여야 하는데, `sheet` 는 자기 카드 모양을 강제한다.
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
        .accessibilityLabel(session.account == nil ? "메뉴, 로그인" : "메뉴, 마이페이지")
        .fullScreenCover(isPresented: $isPresented) {
            AccountDrawerView()
                .presentationBackground(.clear)
        }
    }
}
