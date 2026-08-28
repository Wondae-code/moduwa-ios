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
        case nickname(email: String, password: String)
        case verifyIntro
        case verifyCode
        case resetPassword
    }

    @State private var path: [Route] = []
    /// 비밀번호를 바꾼 뒤처럼, 관문·로그인 화면 위에 남겨야 하는 안내.
    @State private var notice: String?

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
                onNext: { email, password in
                    path.append(.nickname(email: email, password: password))
                },
                // "이미 계정이 있습니다" — 로그인 화면 하나만 남긴다.
                onSignIn: { path = [.signIn] }
            )

        case .nickname(let email, let password):
            // 가입 요청이 여기서 나간다. 성공하면 경로를 **치운다** —
            //  이미 가입한 사람이 뒤로 가서 다시 가입할 자리는 없다.
            SignUpNicknameView(email: email, password: password) {
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
