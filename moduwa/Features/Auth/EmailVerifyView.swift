import SwiftUI

/// 이메일 인증 안내 (시안 868:436 "00. 회원가입 - 이메일인증 중간화면").
///
/// 시안이 코드 입력 앞에 한 장을 더 둔다. 가입 직후에는 아직 메일이 도착하지 않았을 수 있어
/// 빈 칸 여섯 개를 먼저 보여 주면 사용자가 멈춰 선다 — "메일함을 확인하라"는 말을 먼저 한다.
///
/// **막는 화면이 아니다.** 인증하지 않아도 글쓰기·저장은 되므로(서버가 요구하지 않는다)
/// 시안의 뒤로가기 화살표는 이 흐름에서 **"나중에 하기"** 로 동작한다 — 계정은 이미
/// 만들어졌으니 앞 화면(닉네임)으로 돌아갈 자리가 없다.
struct EmailVerifyIntroView: View {
    var onNext: () -> Void
    /// 뒤로가기 = 인증을 미루고 흐름을 닫는다.
    var onSkip: () -> Void

    @Environment(SessionStore.self) private var session

    private var email: String { session.account?.email ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            Text("이메일 주소를 인증해주세요")
                .font(.notoSans(20, .medium, relativeTo: .title3))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 100)
                .accessibilityAddTraits(.isHeader)

            // 주소는 **한 줄로 떼어 놓는다.** "\(email) 으로 …" 처럼 문장에 끼우면 조사가
            //  어긋난다(메일 주소의 끝 글자에 따라 "으로/로"가 갈린다).
            if !email.isEmpty {
                Text(email)
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .padding(.top, 12)
            }

            // 인증이 필요한 실질적 이유는 **비밀번호를 잊었을 때 계정을 되찾는 것**이다.
            //  시안에는 없는 한 줄이지만, 없으면 사용자는 왜 하는지 모른 채 화면을 넘긴다.
            Text("인증해 두면 비밀번호를 잊어도 계정을 되찾을 수 있어요.")
                .font(.notoSans(14, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 24)

            Image("email_envelope")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 159)
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            AuthPrimaryButton(title: "다음으로", action: onNext)
                .padding(.bottom, Spacing.xxl)
        }
        .padding(.horizontal, AuthMetrics.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // 계정은 이미 만들어졌다 — 시스템 뒤로가기는 닉네임 화면으로 돌아가므로 막고,
        //  시안의 화살표 자리에 "미루기"를 둔다.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onSkip) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityLabel("나중에 인증하기")
            }
        }
    }
}

/// 6자리 인증코드 입력 (시안 868:455 / 868:491 "00. 회원가입 - 이메일인증").
struct EmailVerifyCodeView: View {
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
    /// 이 화면에서 다시 보낸 횟수. 시안의 토스트가 "(1/5)" 로 세어 보여 준다.
    ///
    /// **서버가 알려 주는 값이 아니다** — 재발송 API 응답에 남은 횟수가 없어서 화면이 직접 센다.
    /// 화면을 나갔다 들어오면 0 부터 다시 센다. 상한 자체는 서버가 지키고, 넘기면
    /// 서버 문구가 그대로 오류로 뜬다.
    @State private var resendCount = 0

    private static let resendInterval = 60
    /// 시안 문구 "※ 재전송 횟수는 5회로 제한됩니다." 와 같은 값.
    private static let resendLimit = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 시안은 오류와 재전송 안내를 **박스 위**에 둔다(868:491 / 868:529).
                //  자리를 늘 비워 두어 메시지가 뜰 때 박스가 아래로 밀리지 않게 한다.
                statusSlot
                    .padding(.top, 12)

                CodeField(code: $code, hasError: errorMessage != nil) {
                    // 여섯 자리가 채워지면 바로 확인한다 — 무장애 앱에서 "다음 버튼 찾기"를
                    //  한 번 줄이는 값이 크다. 실패해도 고쳐 넣을 수 있다.
                    Task { await verify() }
                }

                Text("이메일로 전송된 인증코드를 입력해주세요.\n(유효시간 10분)")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)

                AuthPrimaryButton(
                    title: "이메일 인증",
                    isEnabled: code.count == CodeField.length,
                    isBusy: isBusy
                ) {
                    Task { await verify() }
                }
                .padding(.top, 16)

                VStack(spacing: 0) {
                    Text("이메일을 받지 못하셨나요?")
                        .font(.notoSans(12, relativeTo: .caption))
                        .foregroundStyle(.textSecondary)

                    Button {
                        Task { await resend() }
                    } label: {
                        Text(resendCountdown > 0 ? "다시 보내기 (\(resendCountdown)초)" : "다시 보내기")
                            .font(.notoSans(16, .medium, relativeTo: .headline))
                            .foregroundStyle(resendCountdown > 0 ? .iconGray : .textPrimary)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(resendCountdown > 0 || isBusy)

                    Text("※ 재전송 횟수는 5회로 제한됩니다.")
                        .font(.notoSans(12, relativeTo: .caption))
                        .foregroundStyle(.deepGreen)
                        .padding(.top, 4)
                }
                .padding(.top, 60)

                // 시안에 없지만 남긴다 — 인증은 글쓰기·저장의 조건이 아니라서(서버가 요구하지
                //  않는다) 메일이 끝내 오지 않는 사람에게 나갈 문이 있어야 한다.
                Button(action: onDone) {
                    Text("나중에 하기")
                        .font(.notoSans(14, .medium, relativeTo: .subheadline))
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .padding(.top, 16)
                .accessibilityHint("인증을 건너뛰고 계속 사용합니다")
            }
            .padding(.horizontal, AuthMetrics.horizontal)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await countDown() }
    }

    /// 오류 한 줄 / 재전송 토스트가 번갈아 앉는 자리. 시안의 두 프레임 모두 높이 36이다.
    @ViewBuilder
    private var statusSlot: some View {
        ZStack {
            if let errorMessage {
                AuthInlineError(message: errorMessage)
            } else if let notice {
                AuthToast(message: notice)
            }
        }
        .frame(minHeight: 36)
    }

    private func verify() async {
        guard code.count == CodeField.length, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.verifyEmail(code: code)
            UIAccessibility.post(notification: .announcement, argument: "이메일을 인증했어요")
            onDone()
        } catch AuthError.invalidCode {
            // 시안 868:491 의 문구를 **마침표 없이** 그대로 쓴다 — `AuthError` 쪽은 다른
            //  메시지들과 맞추려고 마침표가 붙어 있다.
            let message = "인증코드가 일치하지 않습니다"
            errorMessage = message
            notice = nil
            // 틀린 코드는 지운다 — 남겨 두면 다음 시도에서 앞자리를 지우다 또 틀린다.
            code = ""
            UIAccessibility.post(notification: .announcement, argument: message)
        } catch {
            let message = (error as? AuthError)?.errorDescription
                ?? "인증하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            notice = nil
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
                resendCount += 1
                // 시안 868:529 의 토스트 문구 그대로.
                notice = "새로운 인증코드를 다시 전송했습니다. (\(resendCount)/\(Self.resendLimit))"
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
                ?? "인증코드를 보내지 못했어요. 잠시 후 다시 시도해 주세요."
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

#Preview("이메일 인증 안내") {
    NavigationStack {
        EmailVerifyIntroView(onNext: {}, onSkip: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}

#Preview("이메일 인증 코드") {
    NavigationStack {
        EmailVerifyCodeView(onDone: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
