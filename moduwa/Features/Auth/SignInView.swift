import SwiftUI

/// 이메일 로그인 (시안 868:353 / 868:672 / 868:695 / 868:751).
///
/// 관문(`SignInGateView`)에서 "이메일로 시작하기"를 누르면 여기로 온다 — 소셜 버튼은 앞 화면이
/// 이미 보여 줬으므로 이 화면에는 없다(시안도 그렇다).
///
/// 실패 사유를 나누어 보여 주지 않는다 — 서버가 "없는 계정"과 "틀린 비밀번호"를 구분해 주지
/// 않기 때문이다(구분해 주면 그것만으로 어떤 이메일이 가입돼 있는지 알아낼 수 있다).
/// 시안의 문구도 "이메일 혹은 비밀번호가 일치하지 않습니다."로 한 가지다.
struct SignInView: View {
    /// 왜 로그인 창이 떴는지. 쓰기 진입점에서 막혔을 때 그 이유를 위에 보여 준다.
    var reason: String?
    /// 로그인 성공. 보통은 시트를 닫는다.
    var onSignedIn: () -> Void
    var onSignUp: () -> Void
    var onForgotPassword: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    /// 시안 868:773 의 체크박스. **기본값을 켜 둔다** — 시안의 첫 상태(868:353)는 꺼져
    /// 있지만, 꺼진 채로 로그인하면 앱을 다시 켤 때마다 로그아웃돼 있다. 지금까지 이 앱은
    /// 항상 유지해 왔으므로 그 동작을 기본으로 남기고, 끄고 싶은 사람에게 끌 자리를 준다.
    @State private var keepSignedIn = true
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    AuthTitle(text: "로그인")
                        .padding(.top, 16)

                    if let reason {
                        Text(reason)
                            .font(.notoSans(14, relativeTo: .subheadline))
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }

                    AuthField(
                        title: "이메일",
                        placeholder: "moduwa@gmail.com",
                        text: $email,
                        keyboard: .emailAddress,
                        contentType: .username,
                        // 오류는 칸 하나에 붙이지 않는다 — 서버가 어느 쪽이 틀렸는지 알려 주지
                        //  않으므로 두 칸의 보더를 함께 빨갛게 하고 이유는 버튼 위에 한 줄로 둔다.
                        hasError: errorMessage != nil
                    )
                    .padding(.top, 32)

                    AuthField(
                        title: "비밀번호",
                        text: $password,
                        isSecure: true,
                        contentType: .password,
                        submitLabel: .go,
                        hasError: errorMessage != nil,
                        onSubmit: { Task { await submit() } }
                    )
                    .padding(.top, 20)

                    HStack(spacing: 0) {
                        AuthCheckbox(title: "로그인 상태 유지", isOn: $keepSignedIn)
                        Spacer(minLength: 8)
                        AuthLinkButton(title: "비밀번호를 잊으셨나요?", action: onForgotPassword)
                    }
                    .padding(.top, 4)

                    AuthErrorLine(message: errorMessage)
                        .padding(.top, 4)

                    AuthPrimaryButton(title: "로그인", isEnabled: canSubmit, isBusy: isBusy) {
                        Task { await submit() }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, AuthMetrics.horizontal)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            AuthFooterLink(message: "아직 계정이 없으신가요?", actionTitle: "회원가입", action: onSignUp)
                .padding(.bottom, Spacing.s)
        }
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        guard canSubmit, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                keepSignedIn: keepSignedIn
            )
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
        } catch AuthError.invalidCredentials {
            // 시안의 문구를 그대로 쓴다.
            let message = "이메일 혹은 비밀번호가 일치하지 않습니다."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        } catch {
            let message = (error as? AuthError)?.errorDescription
                ?? "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }
}

#Preview("로그인") {
    NavigationStack {
        SignInView(onSignedIn: {}, onSignUp: {}, onForgotPassword: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("입력이 틀린 경우") {
    NavigationStack {
        SignInView(onSignedIn: {}, onSignUp: {}, onForgotPassword: {})
    }
    .environment(SessionStore(service: MockAuthService(failure: .invalidCredentials)))
}
