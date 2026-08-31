import SwiftUI

/// 홈 헤더 오른쪽의 **톱니** — 설정(마이페이지)으로 가는 문.
///
/// 예전에는 네 탭이 모두 같은 자리에 햄버거를 두고 있었다. 새 시안에서 그것이 정리됐다 —
/// **홈 헤더의 아이콘이 검색·알림·톱니로 바뀌고(17:6 의 `Setting` 978:945), 플랜·일정·저장
/// 헤더에는 아이콘이 아예 없다**(제목만). 그래서 설정 진입점은 홈 하나로 모인다.
///
/// **목적지를 이 버튼이 직접 민다.** 새 시안(977:662)의 설정은 탭바가 남은 전체 화면이라
/// 탭 안에서 밀어 올려야 하는데, 이 버튼이 네 탭의 `NavigationStack` 안에 있으므로 여기에
/// 목적지를 붙이면 네 탭이 각자의 스택에서 같은 화면을 민다 — 탭마다 따로 손볼 것이 없다.
/// (예전 판은 오른쪽에서 나오는 서랍이라 `RootView` 가 탭바 위에 그려야 했다.)
struct SettingsButton: View {
    @Environment(SessionStore.self) private var session

    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            // 시안은 26 박스 안에 24 아트워크를 담는다(978:945 → 978:846).
            Image("setting")
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.account == nil ? "설정, 로그인" : "설정")
        .navigationDestination(isPresented: $isPresented) {
            AccountSettingsView()
        }
    }
}
