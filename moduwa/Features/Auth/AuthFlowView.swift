import SwiftUI

/// 로그인 시트의 뼈대 — 로그인 → (가입 → 인증번호) / (비밀번호 찾기).
///
/// 쓰기 진입점에서 막혔을 때 `RootView` 가 이 시트를 띄운다. 왜 떴는지(`prompt`)를 로그인
/// 화면 위에 그대로 보여 준다.
struct AuthFlowView: View {
    let prompt: AuthPrompt

    @Environment(\.dismiss) private var dismiss

    private enum Route: Hashable { case signUp, resetPassword, verifyEmail }

    @State private var path: [Route] = []
    /// 비밀번호를 바꾼 뒤처럼, 로그인 화면 위에 남겨야 하는 안내.
    @State private var notice: String?

    var body: some View {
        NavigationStack(path: $path) {
            SignInView(
                reason: notice ?? prompt.message,
                onSignedIn: { dismiss() },
                onSignUp: { path.append(.signUp) },
                onForgotPassword: { path.append(.resetPassword) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .signUp:
                    SignUpView(
                        // 가입 직후 인증번호 화면으로 이어 준다. 가입 화면을 경로에서 **치운다** —
                        //  이미 가입한 사람이 뒤로 가서 다시 가입할 자리는 없다.
                        onSignedUp: { path = [.verifyEmail] },
                        // 구글은 이메일이 이미 검증된 상태로 들어온다 — 바로 닫는다.
                        onSocialSignedIn: { dismiss() },
                        onSignIn: { path.removeAll() }
                    )
                case .resetPassword:
                    PasswordResetView { _ in
                        // 서버가 모든 세션을 끊었다. 로그인 화면으로 돌려보내고 이유를 남긴다.
                        notice = "비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요."
                        path.removeAll()
                    }
                case .verifyEmail:
                    EmailVerifyView { dismiss() }
                        // 이미 로그인된 상태라 뒤로 갈 곳이 없다.
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview("쓰기에서 막힘") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            AuthFlowView(prompt: .writePost)
                .environment(SessionStore(service: MockAuthService()))
        }
}
