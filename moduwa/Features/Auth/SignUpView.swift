import SwiftUI

/// 이메일 가입 1/2 — 이메일·비밀번호 (시안 868:623 / 868:578 / 868:405).
///
/// 예전 판은 이 화면에서 곧바로 서버에 가입을 요청했다. 새 시안은 **닉네임을 다음 장에서**
/// 묻고 그 장의 버튼이 "회원가입"이다 — 그래서 실제 가입 요청은 `SignUpNicknameView` 가
/// 보내고, 이 화면은 입력만 검사해서 넘긴다. 왕복 한 번으로 끝나므로 중간에 계정이
/// 반쯤 만들어지는 상태가 없다.
///
/// 비밀번호 규칙은 시안 문구를 따른다 — "숫자를 포함하여 8자 이상". 서버는 8자 이상만
/// 요구하므로(`password.ts`) 앱이 한 겹 더 좁게 받는 셈이고, 그래서 서버가 거절할 일은 없다.
struct SignUpView: View {
    /// 입력을 다 받았다 — 닉네임 화면으로 넘긴다. 동의 내용도 함께 넘긴다:
    /// 민감정보 동의 여부가 **가입 요청에 무장애 항목을 실을지**를 정한다.
    var onNext: (_ email: String, _ password: String, _ consent: AuthConsent) -> Void
    /// "이미 계정이 있습니다" — 로그인 화면으로 돌려보낸다.
    var onSignIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    /// 약관·개인정보·민감정보 동의. 앞의 둘은 가입의 전제이고(약관 제5조),
    /// 민감정보는 **선택**이다(`AuthConsent` 주석).
    @State private var consent = AuthConsent()

    /// 서버 정책(`password.ts`)과 같은 하한. 여기에 "숫자 포함"을 더한 것이 시안의 규칙이다.
    private static let passwordMinimum = 8

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }

    /// 형식만 본다. **가입 가능 여부는 서버가 안다** — 앱이 정규식으로 더 깐깐하게 굴면
    /// 멀쩡한 주소(`+` 별칭, 새 TLD)를 막는다.
    private var isEmailValid: Bool {
        let parts = trimmedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
    }

    private var isPasswordValid: Bool {
        password.count >= Self.passwordMinimum && password.contains(where: \.isNumber)
    }

    private var isConfirmValid: Bool {
        !passwordConfirm.isEmpty && passwordConfirm == password
    }

    private var canSubmit: Bool {
        isEmailValid && isPasswordValid && isConfirmValid && consent.hasRequired
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    AuthTitle(text: "회원가입")
                        .padding(.top, 16)

                    AuthField(
                        title: "이메일",
                        placeholder: "moduwa@gmail.com",
                        text: $email,
                        keyboard: .emailAddress,
                        contentType: .username,
                        errorMessage: email.isEmpty || isEmailValid
                            ? nil : "이메일 형식이 올바르지 않습니다."
                    )
                    .padding(.top, 32)

                    AuthField(
                        title: "비밀번호",
                        text: $password,
                        isSecure: true,
                        // `.newPassword` 라야 iOS 가 "강력한 암호"를 제안하고 키체인에 저장한다.
                        contentType: .newPassword,
                        // 시안은 이 문장을 **입력 전에도** 규칙 안내로 보여 준다(868:623).
                        //  틀린 뒤에만 보여 주면 사용자는 한 번 틀려야 규칙을 안다.
                        errorMessage: isPasswordValid
                            ? nil : "비밀번호는 숫자를 포함하여 8자 이상이어야 합니다.",
                        isValid: isPasswordValid
                    )
                    .padding(.top, 20)

                    AuthField(
                        title: "비밀번호 확인",
                        text: $passwordConfirm,
                        isSecure: true,
                        contentType: .newPassword,
                        submitLabel: .next,
                        errorMessage: passwordConfirm.isEmpty || isConfirmValid
                            ? nil : "비밀번호가 일치하지 않습니다.",
                        isValid: isConfirmValid,
                        onSubmit: submit
                    )
                    .padding(.top, 20)

                    AuthConsentSection(
                        consent: $consent,
                        // 저장할 무장애 항목이 없으면 민감정보 줄을 두지 않는다.
                        hasAccessFeatures: !(OnboardingProfileStore.shared.selectionForSignUp ?? []).isEmpty
                    )
                    .padding(.top, 24)

                    AuthPrimaryButton(title: "다음으로", isEnabled: canSubmit, action: submit)
                        .padding(.top, 20)

                    Button(action: onSignIn) {
                        Text("이미 계정이 있습니다")
                            .font(.notoSans(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 37)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, AuthMetrics.horizontal)
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        guard canSubmit else { return }
        onNext(trimmedEmail, password, consent)
    }
}

#Preview("가입 — 첫 화면") {
    NavigationStack {
        SignUpView(onNext: { _, _, _ in }, onSignIn: {})
    }
}
