import SwiftUI

/// 마이페이지 서랍을 열어 둔 상태. **앱 껍데기가 쥔다.**
///
/// 서랍은 탭바까지 덮으므로(시안 821:103) 탭 안쪽에서 띄울 수 없다. 여는 버튼
/// (`AccountMenuButton`)은 네 탭의 헤더에 흩어져 있고 그리는 자리는 `RootView` 하나라서,
/// 그 사이를 잇는 값 하나만 여기 둔다.
///
/// `fullScreenCover` 를 쓰지 않는 이유: 시트·전체화면은 **아래에서 위로** 올라온다.
/// 서랍은 옆에서 나와야 서랍으로 읽히고, 그 전환은 뷰 계층 안의 오버레이일 때만
/// 우리가 정할 수 있다.
/// `@MainActor` 를 붙이지 않는다 — `EnvironmentValues` 의 기본값은 액터 바깥에서 만들어지고,
/// 이 값을 읽고 쓰는 곳은 모두 뷰(메인 액터)다.
@Observable
final class AccountDrawerPresenter {
    var isPresented = false

    /// 열기·닫기를 한곳에서 애니메이션과 함께 처리한다 — 호출부마다 `withAnimation` 을
    /// 다시 쓰면 여는 속도와 닫는 속도가 어긋난다.
    func open() {
        withAnimation(.easeOut(duration: 0.28)) { isPresented = true }
    }

    func close() {
        withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
    }
}

extension EnvironmentValues {
    @Entry var accountDrawer = AccountDrawerPresenter()
}
