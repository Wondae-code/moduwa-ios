import SwiftUI

/// 이메일 인증 — 메일로 받은 6자리 숫자를 넣는다.
///
/// **막는 화면이 아니다.** 인증하지 않아도 글쓰기·저장은 되므로(서버가 요구하지 않는다)
/// "나중에 하기"를 항상 남긴다. 인증이 필요한 실질적 이유는 **비밀번호를 잊었을 때 계정을
/// 되찾는 것**이라, 그 사실을 설명에 적어 준다 — 그러지 않으면 사용자는 왜 하는지 모른다.
struct EmailVerifyView: View {
    /// 인증을 마쳤거나 미뤘다. 보통은 시트를 닫는다.
    var onDone: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var code = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var notice: String?
    /// 재발송까지 남은 초. 서버가 60초 간격을 강제하므로 화면도 같은 값을 센다 —
    /// 누를 수 있는 것처럼 두면 429 를 받고 나서야 알게 된다.
    @State private var resendCountdown = 0

    private static let resendInterval = 60

    private var email: String { session.account?.email ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                AuthHeader(
                    title: "이메일을 확인해 주세요",
                    subtitle: email.isEmpty
                        ? "메일로 보낸 6자리 인증번호를 넣어 주세요."
                        : "\(email) 으로 6자리 인증번호를 보냈어요. 인증해 두면 비밀번호를 잊어도 계정을 되찾을 수 있어요."
                )

                CodeField(code: $code) {
                    // 여섯 자리가 채워지면 바로 확인한다 — 무장애 앱에서 "다음 버튼 찾기"를
                    //  한 번 줄이는 값이 크다. 실패해도 코드는 남아 고쳐 넣을 수 있다.
                    Task { await verify() }
                }

                Button {
                    Task { await resend() }
                } label: {
                    Text(resendCountdown > 0
                         ? "인증번호 다시 받기 (\(resendCountdown)초)"
                         : "인증번호 다시 받기")
                        .font(.notoSans(14, .medium, relativeTo: .subheadline))
                        .foregroundStyle(resendCountdown > 0 ? .iconGray : .deepGreen)
                        .underline(resendCountdown == 0)
                }
                .buttonStyle(.plain)
                .disabled(resendCountdown > 0 || isBusy)

                if let notice {
                    Text(notice)
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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
        .task { await countDown() }
    }

    private var submitBar: some View {
        VStack(spacing: Spacing.m) {
            AuthErrorLine(message: errorMessage)

            AuthPrimaryButton(
                title: "인증하기",
                isEnabled: code.count == CodeField.length,
                isBusy: isBusy
            ) {
                Task { await verify() }
            }

            Button(action: onDone) {
                Text("나중에 하기")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityHint("인증을 건너뛰고 계속 사용합니다")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private func verify() async {
        guard code.count == CodeField.length, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.verifyEmail(code: code)
            UIAccessibility.post(notification: .announcement, argument: "이메일을 인증했어요")
            onDone()
        } catch {
            let message = (error as? AuthError)?.errorDescription
                ?? "인증하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            // 틀린 코드는 지운다 — 남겨 두면 다음 시도에서 앞자리를 지우다 또 틀린다.
            code = ""
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }

    private func resend() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        notice = nil
        do {
            let alreadyVerified = try await session.resendVerificationCode()
            if alreadyVerified {
                UIAccessibility.post(notification: .announcement, argument: "이미 인증된 계정이에요")
                onDone()
            } else {
                notice = "인증번호를 다시 보냈어요. 메일함을 확인해 주세요."
                resendCountdown = Self.resendInterval
                UIAccessibility.post(notification: .announcement, argument: notice)
                await countDown()
            }
        } catch AuthError.resendTooSoon(let seconds) {
            resendCountdown = seconds
            errorMessage = AuthError.resendTooSoon(seconds: seconds).errorDescription
            await countDown()
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription
                ?? "인증번호를 보내지 못했어요. 잠시 후 다시 시도해 주세요."
        }
        isBusy = false
    }

    /// 남은 초를 1초씩 줄인다. 화면이 사라지면 `task` 가 취소돼 함께 멈춘다.
    private func countDown() async {
        while resendCountdown > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            resendCountdown -= 1
        }
    }
}

#Preview("이메일 인증") {
    NavigationStack {
        EmailVerifyView(onDone: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
