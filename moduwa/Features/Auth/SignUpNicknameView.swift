import SwiftUI

/// 이메일 가입 2/2 — 닉네임 (시안 868:566 "00. 회원가입").
///
/// 이 화면의 버튼이 "회원가입"이다 — 그래서 **서버에 실제로 가입 요청을 보내는 곳도 여기다**.
/// 온보딩에서 고른 무장애 항목이 이 요청에 함께 실려 계정에 저장된다
/// (`OnboardingProfileStore` → `SessionStore.signUp`). 가입 전에는 서버에 아무것도 만들지
/// 않으므로 "가입했더니 내 것이 사라졌다"가 생기지 않는다.
///
/// ⚠️ **시안과 순서가 하나 다르다.** 디자이너의 화살표는 이메일 인증을 **마친 뒤** 이 화면으로
/// 오지만, 닉네임만 따로 고치는 API 가 서버에 없다(`PATCH /v1/auth/me` 는 `accessFeatures`
/// 만 받는다). 인증 뒤에 두면 여기서 정한 이름을 저장할 방법이 없어 화면이 거짓말을 한다.
/// 닉네임은 `POST /v1/auth/email/sign-up` 이 받으므로 **가입 요청 직전**으로 옮겼다 —
/// 화면 자체와 문구("회원가입이 거의 끝났어요")는 시안 그대로다.
struct SignUpNicknameView: View {
    let email: String
    let password: String
    /// 가입 성공 — 이메일 인증 안내로 이어 준다(메일은 가입과 동시에 이미 발송됐다).
    var onSignedUp: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var nickname = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    /// 서버 정책(`invalid_nickname`)과 같은 상한.
    private static let nicknameMaximum = 40

    private var trimmed: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        !trimmed.isEmpty && trimmed.count <= Self.nicknameMaximum
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("회원가입이 거의 끝났어요!\n이제 닉네임을 정해볼까요?")
                        .font(.notoSans(16, relativeTo: .body))
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    AuthField(
                        title: "닉네임",
                        placeholder: "모두와",
                        text: $nickname,
                        contentType: .nickname,
                        submitLabel: .go,
                        errorMessage: trimmed.count > Self.nicknameMaximum
                            ? "닉네임은 \(Self.nicknameMaximum)자 이하여야 합니다." : nil,
                        onSubmit: { Task { await submit() } }
                    )
                    .padding(.top, 44)

                    Text("정하신 닉네임은\n프로필 및 커뮤니티에서 사용됩니다.\n개인설정에서 수정 가능해요!")
                        .font(.notoSans(16, relativeTo: .body))
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 96)

                    AuthErrorLine(message: errorMessage)
                        .padding(.top, 24)
                }
                .padding(.horizontal, AuthMetrics.horizontal)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            AuthPrimaryButton(title: "회원가입", isEnabled: canSubmit, isBusy: isBusy) {
                Task { await submit() }
            }
            .padding(.horizontal, AuthMetrics.horizontal)
            .padding(.bottom, Spacing.l)
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
            try await session.signUp(email: email, password: password, nickname: trimmed)
            UIAccessibility.post(notification: .announcement, argument: "가입했어요")
            onSignedUp()
        } catch AuthError.emailTaken {
            // 가입은 "이미 있는 이메일"을 알려 줘야 한다 — 안 알려 주면 사용자가 가입을 못 한다.
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

#Preview("가입 — 닉네임") {
    NavigationStack {
        SignUpNicknameView(email: "moduwa@gmail.com", password: "moduwa08", onSignedUp: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
