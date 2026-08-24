import SwiftUI

/// 비밀번호 찾기 — 주소 입력 → 6자리 인증번호 + 새 비밀번호.
///
/// ⚠️ **가입 여부를 알려주지 않는다.** 서버가 없는 주소에도 같은 성공 응답을 주므로
/// 이 화면도 "가입된 주소라면 보냈어요"까지만 말한다. 여기서 갈리면 그것만으로 가입된
/// 이메일 목록을 만들 수 있고, 그 목록이 곧 무차별 대입 대상이 된다.
struct PasswordResetView: View {
    /// 비밀번호를 바꿨다. 서버가 **모든 세션을 끊었으므로** 로그인 화면으로 돌려보낸다.
    var onReset: (String) -> Void

    @Environment(SessionStore.self) private var session

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private static let passwordMinimum = 8

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }

    private var canSubmit: Bool {
        switch step {
        case .email: !trimmedEmail.isEmpty
        case .code: code.count == CodeField.length && newPassword.count >= Self.passwordMinimum
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                switch step {
                case .email:
                    AuthHeader(
                        title: "비밀번호 찾기",
                        subtitle: "가입한 이메일 주소를 넣어 주세요. 6자리 인증번호를 보내 드려요."
                    )
                    AuthField(
                        title: "이메일",
                        placeholder: "moduwa@example.com",
                        text: $email,
                        keyboard: .emailAddress,
                        contentType: .username,
                        submitLabel: .send,
                        onSubmit: { Task { await submit() } }
                    )

                case .code:
                    AuthHeader(
                        title: "새 비밀번호",
                        subtitle: "가입된 주소라면 인증번호를 보냈어요. 메일의 6자리 숫자와 새 비밀번호를 넣어 주세요."
                    )
                    CodeField(code: $code)
                    AuthField(
                        title: "새 비밀번호",
                        placeholder: "\(Self.passwordMinimum)자 이상",
                        text: $newPassword,
                        isSecure: true,
                        contentType: .newPassword,
                        submitLabel: .go,
                        onSubmit: { Task { await submit() } }
                    )
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

            AuthPrimaryButton(
                title: step == .email ? "인증번호 받기" : "비밀번호 바꾸기",
                isEnabled: canSubmit,
                isBusy: isBusy
            ) {
                Task { await submit() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private func submit() async {
        guard canSubmit, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            switch step {
            case .email:
                try await session.requestPasswordReset(email: trimmedEmail)
                // 없는 주소여도 여기로 온다. 다음 단계에서 코드가 틀리다고 알려 줄 뿐이다.
                withoutAnimation { step = .code }
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "가입된 주소라면 인증번호를 보냈어요. 인증번호와 새 비밀번호를 넣어 주세요.")

            case .code:
                try await session.resetPassword(
                    email: trimmedEmail, code: code, newPassword: newPassword)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "비밀번호를 바꿨어요. 다시 로그인해 주세요.")
                onReset(trimmedEmail)
            }
        } catch {
            let message = (error as? AuthError)?.errorDescription
                ?? "처리하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }
}

#Preview("비밀번호 찾기") {
    NavigationStack {
        PasswordResetView(onReset: { _ in })
    }
    .environment(SessionStore(service: MockAuthService()))
}
