import SwiftUI

/// 이메일 가입.
///
/// 온보딩에서 고른 무장애 항목이 **이 요청에 함께 실려** 계정에 저장된다
/// (`OnboardingProfileStore` → `SessionStore.signUp`). 가입 전에는 서버에 아무것도 만들지
/// 않으므로 "가입했더니 내 것이 사라졌다"가 생기지 않는다.
struct SignUpView: View {
    /// 이메일 가입 성공 — 인증번호 화면으로 이어 준다(메일은 가입과 동시에 이미 발송됐다).
    var onSignedUp: () -> Void
    /// 소셜로 들어온 경우. **인증번호 화면으로 보내지 않는다** — 구글이 이메일 소유를 이미
    /// 확인해 줬고 서버도 그 계정을 인증된 것으로 표시한다. 보낼 코드가 없으므로 그 화면은
    /// 영원히 통과할 수 없는 벽이 된다.
    var onSocialSignedIn: () -> Void
    /// "이미 계정이 있어요" — 로그인 화면으로 돌려보낸다.
    var onSignIn: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    /// 서버 정책과 같은 값(`password.ts`). 여기서 먼저 걸러 주면 왕복 한 번을 아낀다.
    private static let passwordMinimum = 8

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
    private var trimmedNickname: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        !trimmedEmail.isEmpty && password.count >= Self.passwordMinimum
    }

    /// 온보딩에서 고른 항목. 가입과 함께 계정에 저장된다는 사실을 화면에서도 알려 준다 —
    /// 모르고 넘어가면 "그건 어디로 갔지"가 된다.
    private var onboardingSummary: String? {
        let features = OnboardingProfileStore.shared.selectionForSignUp ?? []
        guard !features.isEmpty else { return nil }
        return features.map(\.label).joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                AuthHeader(
                    title: "가입하기",
                    subtitle: "이메일과 비밀번호만 있으면 됩니다. 이름은 나중에 바꿀 수 있어요."
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
                        placeholder: "\(Self.passwordMinimum)자 이상",
                        text: $password,
                        isSecure: true,
                        // `.newPassword` 라야 iOS 가 "강력한 암호"를 제안하고 키체인에 저장한다.
                        contentType: .newPassword
                    )
                    AuthField(
                        title: "이름 (선택)",
                        placeholder: "여행자",
                        text: $nickname,
                        contentType: .nickname,
                        submitLabel: .go,
                        onSubmit: { Task { await submit() } }
                    )
                }

                // 가입도 로그인과 같은 버튼을 쓴다 — 소셜은 계정이 있는지 모르는 채로 누른다.
                SocialSignInSection(isBusy: isBusy) {
                    Task { await signUpWithGoogle() }
                } onKakao: {
                    Task { await signInWithKakao() }
                }

                if let onboardingSummary {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("가입하면 함께 저장돼요")
                            .font(.notoSans(13, .medium))
                            .foregroundStyle(.textSecondary)
                        Text(onboardingSummary)
                            .font(.notoSans(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Radius.badge)
                        .fill(Color.photoPlaceholder))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.white)
        .safeAreaInset(edge: .bottom) { submitBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var submitBar: some View {
        VStack(spacing: Spacing.m) {
            AuthErrorLine(message: errorMessage)

            AuthPrimaryButton(title: "가입하기", isEnabled: canSubmit, isBusy: isBusy) {
                Task { await submit() }
            }

            HStack(spacing: 4) {
                Text("이미 계정이 있나요?")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                Button(action: onSignIn) {
                    Text("로그인")
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

    /// 구글로 가입(=로그인). 이미 있는 계정이면 서버가 그냥 로그인시킨다.
    private func signUpWithGoogle() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.signInWithGoogle()
            UIAccessibility.post(notification: .announcement, argument: "로그인했어요")
            onSocialSignedIn()
        } catch GoogleSignInFlow.Failure.cancelled {
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
            onSocialSignedIn()
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
            try await session.signUp(
                email: trimmedEmail,
                password: password,
                nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
            )
            UIAccessibility.post(notification: .announcement, argument: "가입했어요")
            onSignedUp()
        } catch AuthError.emailTaken {
            // 가입은 "이미 있는 이메일"을 알려 줘야 한다 — 안 알려 주면 사용자가 가입을 못 한다.
            //  로그인으로 가는 길을 문구로 남긴다.
            errorMessage = AuthError.emailTaken.errorDescription
            UIAccessibility.post(
                notification: .announcement, argument: AuthError.emailTaken.errorDescription)
        } catch {
            let message = (error as? AuthError)?.errorDescription
                ?? "가입하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }
}

#Preview("가입") {
    NavigationStack {
        SignUpView(onSignedUp: {}, onSocialSignedIn: {}, onSignIn: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
