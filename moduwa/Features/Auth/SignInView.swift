import SwiftUI

/// 이메일 로그인.
///
/// 실패 사유를 나누어 보여 주지 않는다 — 서버가 "없는 계정"과 "틀린 비밀번호"를 구분해 주지
/// 않기 때문이다(구분해 주면 그것만으로 어떤 이메일이 가입돼 있는지 알아낼 수 있다).
struct SignInView: View {
    /// 왜 로그인 창이 떴는지. 쓰기 진입점에서 막혔을 때 그 이유를 위에 보여 준다 —
    /// "로그인이 필요해요"만 띄우면 사용자는 자기가 무엇을 하려던 중인지 다시 떠올려야 한다.
    var reason: String?
    /// 로그인 성공. 보통은 시트를 닫는다.
    var onSignedIn: () -> Void
    var onSignUp: () -> Void
    var onForgotPassword: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    AuthHeader(
                        title: "로그인",
                        subtitle: reason ?? "이메일로 로그인하면 저장한 장소와 플랜이 기기를 바꿔도 따라옵니다."
                    )

                    VStack(spacing: Spacing.l) {
                        AuthField(
                            title: "이메일",
                            placeholder: "moduwa@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .username
                        )
                        AuthField(
                            title: "비밀번호",
                            placeholder: "8자 이상",
                            text: $password,
                            isSecure: true,
                            contentType: .password,
                            submitLabel: .go,
                            onSubmit: { Task { await submit() } }
                        )
                    }

                    SocialSignInSection(isBusy: isBusy) {
                        Task { await signInWithGoogle() }
                    } onKakao: {
                        Task { await signInWithKakao() }
                    }

                    Button(action: onForgotPassword) {
                        Text("비밀번호를 잊으셨나요?")
                            .font(.notoSans(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(.textSecondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) { submitBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var submitBar: some View {
        VStack(spacing: Spacing.m) {
            AuthErrorLine(message: errorMessage)

            AuthPrimaryButton(
                title: "로그인",
                isEnabled: canSubmit,
                isBusy: isBusy
            ) {
                Task { await submit() }
            }

            HStack(spacing: 4) {
                Text("아직 계정이 없나요?")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                Button(action: onSignUp) {
                    Text("가입하기")
                        .font(.notoSans(14, .bold, relativeTo: .subheadline))
                        .foregroundStyle(.deepGreen)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    /// 구글 로그인. 사용자가 시트를 닫은 것(`cancelled`)은 오류로 보여 주지 않는다.
    private func signInWithGoogle() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.signInWithGoogle()
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
        } catch GoogleSignInFlow.Failure.cancelled {
            // 본인이 닫았다. 아무 말도 하지 않는다.
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "구글 로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }

    /// 카카오 로그인. 카카오톡이 깔려 있으면 앱으로 전환된다.
    private func signInWithKakao() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.signInWithKakao()
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
        } catch KakaoSignInFlow.Failure.cancelled {
            // 본인이 취소했다.
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }

    private func submit() async {
        guard canSubmit, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.signIn(
                email: email.trimmingCharacters(in: .whitespaces), password: password)
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
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

#Preview("쓰기에서 막힌 경우") {
    NavigationStack {
        SignInView(
            reason: AuthPrompt.writePost.message,
            onSignedIn: {}, onSignUp: {}, onForgotPassword: {}
        )
    }
    .environment(SessionStore(service: MockAuthService(failure: .invalidCredentials)))
}
