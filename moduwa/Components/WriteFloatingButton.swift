import SwiftUI

/// 게시글 작성 플로팅 버튼 — 시안 "01. 메인화면"의 Write Button(652:3399).
///
/// 53pt 라임 원 + 딥그린 그림자(#075B39 20%, 반경 10, y2). 시안 여백은 오른쪽 25, 탭바 위 21.
///
/// ⚠️ **하단에 고정 바가 있는 화면에는 쓰지 않는다.** 리뷰 상세처럼 댓글 입력 바가
/// `safeAreaInset(edge: .bottom)` 으로 깔린 화면에서는 이 버튼이 그 위에 겹친다 —
/// 그런 화면은 헤더에 작성 버튼을 둔다(`WriteHeaderButton`).
///
/// **로그인 게이트가 여기 있다.** 게시는 로그인 필수인데(백엔드 030), 서버 401 을 기다리면
/// 사용자가 글을 다 쓴 뒤에 로그인 창을 만난다 — 쓴 것을 잃을까 불안해지는 자리다.
/// 들어가는 문에서 묻는다.
struct WriteFloatingButton: View {
    /// 게시가 **서버에서 성공한 뒤** 불린다. 돌아온 화면이 목록을 다시 받는 자리다.
    ///
    /// ⚠️ 이 콜백이 없으면 방금 쓴 글이 보이지 않는다. 밀린 화면에서 돌아와도 뒤 화면의
    /// `.task` 는 다시 돌지 않는다 — 그 화면은 사라진 적이 없고 덮여 있었을 뿐이다
    /// (2026-08-19 홈에서 실측: 쓴 글이 목록에 나타나지 않았다).
    /// 목록을 들고 있는 화면에서는 반드시 넘긴다.
    var onPosted: (() -> Void)? = nil

    @Environment(SessionStore.self) private var session
    @State private var isComposing = false

    var body: some View {
        Button {
            // 비로그인이면 로그인 시트가 뜨고 작성 화면으로 가지 않는다.
            guard session.requireSignIn(.writePost) else { return }
            isComposing = true
        } label: {
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
        .buttonStyle(.plain)
        .padding(.trailing, 25)
        .padding(.bottom, 21)
        .accessibilityLabel("게시글 작성")
        // 값 경로(`navigationDestination(for:)`)를 쓰지 않는 이유: 화면마다 경로를 등록해야
        //  하고, 등록을 빠뜨린 화면에서 조용히 아무 일도 일어나지 않는다. 이 형태는 어느
        //  `NavigationStack` 안에서든 그대로 밀린다.
        .navigationDestination(isPresented: $isComposing) {
            PostComposeView(onPosted: onPosted)
        }
    }
}

/// 하단이 이미 차 있는 화면(리뷰 상세의 댓글 입력 바)을 위한 작성 버튼.
///
/// 플로팅 원을 그 위에 얹으면 입력창을 가린다. 같은 글리프를 헤더 오른쪽 빈자리에 두어
/// 작성으로 가는 길은 남기고 하단은 건드리지 않는다.
struct WriteHeaderButton: View {
    /// `WriteFloatingButton.onPosted` 와 같다 — 목록을 들고 있는 화면이면 넘긴다.
    var onPosted: (() -> Void)? = nil
    /// 헤더의 글리프. 시안은 자리에 따라 다른 연필을 쓴다 — 저장 탭 헤더(642:1255)는 **연필만**
    /// (`detail_pencil`), 홈의 플로팅 버튼(652:3399)은 **연필+플러스**(`compose_write`)다.
    /// 기본값은 시안이 있는 저장 탭 쪽에 맞춘다.
    var icon: String = "detail_pencil"

    @Environment(SessionStore.self) private var session
    @State private var isComposing = false

    var body: some View {
        Button {
            guard session.requireSignIn(.writePost) else { return }
            isComposing = true
        } label: {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundStyle(Color.deepGreen)
                // 헤더의 다른 버튼과 같은 탭 영역
                .frame(width: 25, height: 25)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("게시글 작성")
        .navigationDestination(isPresented: $isComposing) {
            PostComposeView(onPosted: onPosted)
        }
    }
}
