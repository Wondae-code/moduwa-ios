import SwiftUI

/// 로그인 시트의 뼈대 — 시안 "모두와 UI — 온보딩, 로그인"(868:150)의 흐름을 그대로 잇는다.
///
/// ```
/// 관문(868:645) ─ 이메일로 시작하기 → 로그인(868:353) ─ 비밀번호를 잊으셨나요 → 재설정
///        └ 회원가입 → 가입(868:623) → 닉네임(868:566) → 인증 안내(868:436) → 인증(868:455)
/// ```
///
/// 쓰기 진입점에서 막혔을 때 `RootView` 가 이 시트를 띄운다. 왜 떴는지(`prompt`)를 관문 위에
/// 그대로 보여 준다.
struct AuthFlowView: View {
    let prompt: AuthPrompt

    @Environment(\.dismiss) private var dismiss

    private enum Route: Hashable {
        case signIn
        case signUp
        /// `sensitiveConsent`: 무장애 항목(민감정보)을 계정에 저장해도 되는지.
        /// 가입 요청이 나가는 화면까지 들고 가야 해서 경로에 싣는다.
        case nickname(email: String, password: String, sensitiveConsent: Bool)
        case verifyIntro
        case verifyCode
        case resetPassword
    }

    @Environment(SessionStore.self) private var session

    @State private var path: [Route] = []
    /// 비밀번호를 바꾼 뒤처럼, 관문·로그인 화면 위에 남겨야 하는 안내.
    @State private var notice: String?

    /// 카카오 갈림길 다이얼로그가 띄우고 있는 요청.
    ///
    /// ⚠️ **`session.kakaoLink` 를 그대로 바인딩하지 않는다.** "기존 계정에 연결" 을 고르면
    /// 다이얼로그는 닫혀야 하지만 **토큰은 남아야 한다**(로그인이 끝난 뒤 붙일 것이다).
    /// 저장소 값에 직접 매달면 창을 닫는 순간 토큰까지 사라진다.
    @State private var kakaoPrompt: SessionStore.KakaoLinkRequest?

    var body: some View {
        NavigationStack(path: $path) {
            SignInGateView(
                reason: notice ?? prompt.message,
                onSignedIn: { dismiss() },
                onEmail: { path.append(.signIn) },
                onSignUp: { path.append(.signUp) },
                onClose: { dismiss() }
            )
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
        .presentationDragIndicator(.visible)
        // 카카오가 기존 계정과 같은 주소일 때의 갈림길(서버 409 `link_required`).
        //  ⚠️ 실패가 아니라 **선택**이라 오류 줄이 아니라 창으로 묻는다. 이 시점에 서버에는
        //  아무것도 만들어지지 않았다 — 취소해도 잃는 것이 없다.
        .onChange(of: session.kakaoLink) { _, new in
            if let new { kakaoPrompt = new }
        }
        .alert("이 이메일로 가입된 계정이 있어요",
               isPresented: Binding(get: { kakaoPrompt != nil },
                                    set: { if !$0 { kakaoPrompt = nil } }),
               presenting: kakaoPrompt) { request in
            Button("기존 계정에 연결") { connectExistingAccount(request) }
            Button("새 계정으로 시작") { startSeparateAccount() }
            Button("취소", role: .cancel) { session.cancelKakaoLink() }
        } message: { request in
            Text(Self.kakaoLinkMessage(request))
        }
    }

    /// 무엇을 고르는 것인지 **결과로** 적는다. "연결 / 새 계정" 이라는 말만으로는 무엇이
    /// 달라지는지 알 수 없고, 잘못 고르면 후기·플랜이 빈 계정을 보게 된다.
    ///
    /// 뷰 본문에서 문자열을 이어 붙이면 타입 검사가 느려져 빌드가 멈춘다 — 밖에서 만든다.
    private static func kakaoLinkMessage(_ request: SessionStore.KakaoLinkRequest) -> String {
        """
        기존 계정에 연결하면 지금까지 쓴 후기와 플랜을 그대로 쓸 수 있어요. \(request.guidance)

        새 계정으로 시작하면 기존 계정과 별개가 되고, 예전 글은 그 계정에 남아요.
        """
    }

    /// "기존 계정에 연결" — 여기서는 **길만 안내한다.** 실제 연결은 로그인이 끝난 뒤
    /// `SessionStore` 가 잇는다. `session.kakaoLink` 를 지우지 않는 이유가 그것이다.
    private func connectExistingAccount(_ request: SessionStore.KakaoLinkRequest) {
        kakaoPrompt = nil
        notice = request.guidance
        // 이메일 계정이면 비밀번호를 받아야 하니 로그인 화면으로, 소셜뿐이면 그 버튼이 있는
        //  관문에 그대로 둔다.
        path = request.providers.contains("email") ? [.signIn] : []
    }

    private func startSeparateAccount() {
        kakaoPrompt = nil
        Task {
            do {
                try await session.startSeparateKakaoAccount()
                dismiss()
            } catch {
                notice = (error as? LocalizedError)?.errorDescription
                    ?? "새 계정을 만들지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .signIn:
            SignInView(
                reason: notice,
                onSignedIn: { dismiss() },
                onSignUp: { path.append(.signUp) },
                onForgotPassword: { path.append(.resetPassword) }
            )

        case .signUp:
            SignUpView(
                onNext: { email, password, consent in
                    path.append(.nickname(email: email, password: password,
                                          sensitiveConsent: consent.sensitive))
                },
                // "이미 계정이 있습니다" — 로그인 화면 하나만 남긴다.
                onSignIn: { path = [.signIn] }
            )

        case .nickname(let email, let password, let sensitiveConsent):
            // 가입 요청이 여기서 나간다. 성공하면 경로를 **치운다** —
            //  이미 가입한 사람이 뒤로 가서 다시 가입할 자리는 없다.
            SignUpNicknameView(email: email, password: password,
                               sensitiveConsent: sensitiveConsent) {
                path = [.verifyIntro]
            }

        case .verifyIntro:
            EmailVerifyIntroView(
                onNext: { path.append(.verifyCode) },
                onSkip: { dismiss() }
            )

        case .verifyCode:
            EmailVerifyCodeView { dismiss() }

        case .resetPassword:
            PasswordResetView { _ in
                // 서버가 모든 세션을 끊었다. 로그인 화면으로 돌려보내고 이유를 남긴다.
                notice = "비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요."
                path = [.signIn]
            }
        }
    }
}

#Preview("쓰기에서 막힘") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            AuthFlowView(prompt: .writePost)
                .environment(SessionStore(service: MockAuthService()))
        }
}

/// 카카오 갈림길. 실제로 태우려면 **카카오 주소와 같은 주소로 가입된 계정**이 서버에 있어야
/// 해서 시뮬레이터로는 만들기 어렵다 — 문구와 버튼 배치는 여기서 본다.
#Preview("카카오 — 같은 이메일") {
    let store = SessionStore(service: MockAuthService())
    store.kakaoLink = .init(idToken: "preview", providers: ["email"])
    return Color.white
        .sheet(isPresented: .constant(true)) {
            AuthFlowView(prompt: .writePost).environment(store)
        }
}
