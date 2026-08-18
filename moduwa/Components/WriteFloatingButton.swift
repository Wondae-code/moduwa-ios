import SwiftUI

/// 게시글 작성 플로팅 버튼 — 시안 "01. 메인화면"의 Write Button(652:3399).
///
/// 53pt 라임 원 + 딥그린 그림자(#075B39 20%, 반경 10, y2). 시안 여백은 오른쪽 25, 탭바 위 21.
///
/// `NavigationLink` 의 **목적지 클로저 형태**를 쓴다(값 형태가 아니다) — 값으로 밀면 화면마다
/// `navigationDestination(for:)` 에 경로를 등록해야 하고, 등록을 빠뜨린 화면에서 조용히
/// 아무 일도 일어나지 않는다. 클로저 형태는 어느 `NavigationStack` 안에서든 그대로 동작한다.
///
/// ⚠️ **하단에 고정 바가 있는 화면에는 쓰지 않는다.** 리뷰 상세처럼 댓글 입력 바가
/// `safeAreaInset(edge: .bottom)` 으로 깔린 화면에서는 이 버튼이 그 위에 겹친다 —
/// 그런 화면은 헤더에 작성 버튼을 둔다(`WriteHeaderButton`).
struct WriteFloatingButton: View {
    var body: some View {
        NavigationLink { PostComposeView() } label: {
            Image("compose_write")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 53, height: 53)
                .background(Color.moduwaGreen, in: Circle())
                .shadow(color: Color.deepGreen.opacity(0.2), radius: 10, y: 2)
        }
        .padding(.trailing, 25)
        .padding(.bottom, 21)
        .accessibilityLabel("게시글 작성")
    }
}

/// 하단이 이미 차 있는 화면(리뷰 상세의 댓글 입력 바)을 위한 작성 버튼.
///
/// 플로팅 원을 그 위에 얹으면 입력창을 가린다. 같은 글리프를 헤더 오른쪽 빈자리에 두어
/// 작성으로 가는 길은 남기고 하단은 건드리지 않는다.
struct WriteHeaderButton: View {
    var body: some View {
        NavigationLink { PostComposeView() } label: {
            Image("compose_write")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundStyle(Color.deepGreen)
                // 헤더의 다른 버튼과 같은 탭 영역
                .frame(width: 25, height: 25)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("게시글 작성")
    }
}
