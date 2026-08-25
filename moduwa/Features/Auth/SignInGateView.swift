import SwiftUI

/// 로그인 관문 (시안 868:645 "00. 로그인").
///
/// 예전 판은 로그인 창을 열면 곧바로 이메일·비밀번호 칸이 나왔다. 새 시안은 **어떻게
/// 로그인할지 먼저 고르게** 한다 — 이메일로 시작하기 / 또는 / Google / 카카오.
/// 소셜로 들어오는 사람에게 쓰지 않을 입력칸 두 개를 먼저 보여 줄 이유가 없다.
///
/// 실패 사유를 나누어 보여 주지 않는다 — 서버가 "없는 계정"과 "틀린 비밀번호"를 구분해 주지
/// 않기 때문이다(구분해 주면 그것만으로 어떤 이메일이 가입돼 있는지 알아낼 수 있다).
struct SignInGateView: View {
    /// 왜 로그인 창이 떴는지. 쓰기 진입점에서 막혔을 때 그 이유를 위에 보여 준다 —
    /// "로그인이 필요해요"만 띄우면 사용자는 자기가 무엇을 하려던 중인지 다시 떠올려야 한다.
    var reason: String?
    /// 소셜 로그인 성공. 보통은 시트를 닫는다.
    var onSignedIn: () -> Void
    /// "이메일로 시작하기" — 이메일 로그인 폼으로.
    var onEmail: () -> Void
    var onSignUp: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Image("logo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 61)
                        .foregroundStyle(.deepGreen)
                        .padding(.top, 60)
                        .accessibilityHidden(true)

                    Text("안녕하세요, 모두와입니다")
                        .font(.notoSans(20, .medium, relativeTo: .title3))
                        .foregroundStyle(.textPrimary)
                        .padding(.top, 36)
                        .accessibilityAddTraits(.isHeader)

                    if let reason {
                        Text(reason)
                            .font(.notoSans(14, relativeTo: .subheadline))
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }

                    AuthPrimaryButton(title: "이메일로 시작하기", isEnabled: !isBusy, action: onEmail)
                        .padding(.top, 60)

                    SocialSignInSection(isBusy: isBusy) {
                        Task { await signIn(with: .google) }
                    } onKakao: {
                        Task { await signIn(with: .kakao) }
                    }
                    .padding(.top, 12)

                    AuthErrorLine(message: errorMessage)
                        .padding(.top, 16)
                }
                .padding(.horizontal, AuthMetrics.horizontal)
                .padding(.bottom, Spacing.xl)
            }

            AuthFooterLink(message: "아직 계정이 없으신가요?", actionTitle: "회원가입", action: onSignUp)
                .padding(.bottom, Spacing.s)
        }
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private enum Provider { case google, kakao }

    /// 소셜 로그인. 사용자가 시트를 닫은 것(`cancelled`)은 오류로 보여 주지 않는다.
    private func signIn(with provider: Provider) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            switch provider {
            case .google: try await session.signInWithGoogle()
            case .kakao: try await session.signInWithKakao()
            }
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
        } catch GoogleSignInFlow.Failure.cancelled, KakaoSignInFlow.Failure.cancelled {
            // 본인이 닫았다. 아무 말도 하지 않는다.
        } catch {
            let fallback = provider == .google
                ? "Google 로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
                : "카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
            let message = (error as? LocalizedError)?.errorDescription ?? fallback
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }
}

#Preview("로그인 관문") {
    NavigationStack {
        SignInGateView(onSignedIn: {}, onEmail: {}, onSignUp: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("쓰기에서 막힌 경우") {
    NavigationStack {
        SignInGateView(
            reason: AuthPrompt.writePost.message, onSignedIn: {}, onEmail: {}, onSignUp: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
