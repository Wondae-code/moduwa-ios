import AuthenticationServices
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
    /// 로그인을 그만두고 시트를 닫는다.
    var onClose: () -> Void

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
                    } onApple: { result in
                        Task { await signInWithApple(result) }
                    }
                    .padding(.top, 12)

                    // 소셜 버튼은 눌리자마자 계정을 만든다 — 동의를 물을 화면이 중간에 없다.
                    //  약관·처리방침은 이 고지로 받고, 민감정보는 받지 않는다(주석 참고).
                    SocialSignInConsentNotice()
                        .padding(.top, 10)

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
        // ⚠️ **여기에 버튼이 있어야 뒤 화면이 흔들리지 않는다.** 이 화면은 시트 안
        //  `NavigationStack` 의 뿌리인데, 바가 완전히 비면 SwiftUI 가 높이를 거의 0으로
        //  접는다. 그 상태에서 "회원가입"을 밀어 넣으면 뒤로가기 버튼이 생기면서 바가 펴지고,
        //  들어오는 화면이 **잠깐 위에 있다가 아래로 내려앉는다**(실기기 확인).
        //  닫기 버튼은 그 높이를 처음부터 잡아 두고, 시트를 내려서만 나갈 수 있던 길도 없앤다.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityLabel("로그인 닫기")
            }
        }
    }

    private enum Provider { case google, kakao }

    /// 애플 로그인. 창을 띄우는 일은 버튼이 이미 했고, 여기는 결과를 서버로 넘긴다.
    /// 사용자가 창을 닫은 것(`cancelled`)은 오류로 보여 주지 않는다 — 구글·카카오와 같은 규칙.
    private func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            let credential = try AppleSignInFlow.credential(from: result)
            try await session.signInWithApple(credential)
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSignedIn()
        } catch AppleSignInFlow.Failure.cancelled {
            // 본인이 닫았다. 아무 말도 하지 않는다.
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Apple 로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }

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
        SignInGateView(onSignedIn: {}, onEmail: {}, onSignUp: {}, onClose: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("쓰기에서 막힌 경우") {
    NavigationStack {
        SignInGateView(
            reason: AuthPrompt.writePost.message,
            onSignedIn: {}, onEmail: {}, onSignUp: {}, onClose: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
