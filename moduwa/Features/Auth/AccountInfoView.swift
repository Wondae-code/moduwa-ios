import SwiftUI

/// 회원정보 수정 — 설정 화면의 이름 옆 연필(`AccountSettingsView`)에서 들어온다.
///
/// **로그아웃이 여기 있다.** 시안(821:103)에는 로그아웃 줄이 없고 "비로그인시" 화면도 없어서,
/// 계정 자체를 다루는 이 줄 안에 두었다 — 이메일 인증과 같은 자리가 맞다. 서랍 첫 화면에
/// 두면 메뉴 다섯 줄 사이에 성격이 다른 동작 하나가 튄다.
///
/// 로그아웃하면 **저장 탭·플랜 탭이 비어야 한다** — 계정 데이터는 서버에 남고 다시 로그인하면
/// 돌아오지만, 로그아웃한 기기에 남아 보이면 안 된다(`SessionStore.onSignedOut`).
struct AccountInfoView: View {
    /// 로그아웃했다. 서랍은 닫혀야 한다 — 로그아웃한 계정의 메뉴가 남아 있으면 안 된다.
    var onSignedOut: () -> Void
    /// 이메일 인증 화면으로. **경로는 서랍이 쥔다** — 밀어 넣는 스택이 하나여야 뒤로 가기가
    /// 어긋나지 않는다(`AccountSettingsView.SubRoute`).
    var onVerifyEmail: () -> Void
    var onChangePassword: () -> Void
    /// 회원 탈퇴 화면으로. **앱스토어 심사 필수**(5.1.1(v)) — 계정을 만들 수 있는 앱은 앱 안에서
    /// 계정 삭제도 제공해야 한다. 로그아웃과 같은 자리에 두지만 아래로, 톤도 다르게 둔다.
    var onDeleteAccount: () -> Void = {}

    @Environment(SessionStore.self) private var session

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if let account = session.account {
                    identityCard(account)

                    if !account.emailVerified, account.email != nil {
                        AuthPrimaryButton(title: "이메일 인증하기", action: onVerifyEmail)
                    }

                    Button(action: onChangePassword) {
                        Text("비밀번호 변경")
                            .font(.notoSans(16, .bold, relativeTo: .headline))
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AuthMetrics.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.card)
                                    .stroke(Color.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    signOutSection
                    deleteAccountLink
                }
            }
            .padding(.horizontal, AuthMetrics.horizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(.white)
        .navigationTitle("회원정보 수정")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 되돌릴 수 없는 동작이라 **버튼처럼 두지 않는다** — 로그아웃보다 작고 조용한 글자 링크다.
    /// 실제 설명과 확인은 다음 화면(`AccountDeleteView`)이 한다.
    private var deleteAccountLink: some View {
        Button(action: onDeleteAccount) {
            Text("회원 탈퇴")
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(.iconGray)
                .underline()
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.s)
        .accessibilityHint("계정을 지우는 화면으로 갑니다")
    }

    private func identityCard(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(account.nickname)
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .foregroundStyle(.textPrimary)
            if let email = account.email {
                Text(email)
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: account.emailVerified
                      ? "checkmark.seal.fill" : "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(account.emailVerified ? .deepGreen : .textSecondary)
                Text(account.emailVerified ? "이메일 인증 완료" : "이메일 인증 전")
                    .font(.notoSans(13, .medium, relativeTo: .footnote))
                    .foregroundStyle(account.emailVerified ? .deepGreen : .textSecondary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
        .accessibilityElement(children: .combine)
    }

    /// 로그아웃.
    ///
    /// 확인창을 두지 않는다.
    /// ① **되돌릴 수 있는 동작이다.** 계정과 데이터는 서버에 남고 다시 로그인하면 돌아온다.
    ///    이 코드베이스가 확인을 받는 것은 플랜 삭제처럼 **되돌릴 수 없는** 일뿐이다.
    /// ② 시트 안에서 시스템 확인창(`alert`·`confirmationDialog`)이 **버튼 동작을 잃는 것을
    ///    실측했다**(2026-08-21: 창은 뜨고 닫히는데 로그아웃이 실행되지 않았다).
    ///    눌러도 아무 일이 없는 버튼보다 바로 로그아웃하는 편이 정직하다.
    private var signOutSection: some View {
        VStack(spacing: Spacing.s) {
            Button {
                Task {
                    await session.signOut()
                    UIAccessibility.post(notification: .announcement, argument: "로그아웃했어요")
                    onSignedOut()
                }
            } label: {
                Text("로그아웃")
                    .font(.notoSans(15, .medium, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AuthMetrics.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card)
                            .stroke(Color.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            // 무엇이 남는지는 **VoiceOver 힌트로만** 알린다. 버튼 아래 같은 말을 한 줄 더 두면
            //  화면이 로그아웃을 말리는 것처럼 읽힌다.
            .accessibilityHint("다시 로그인하면 저장한 장소와 플랜이 그대로 돌아옵니다")
        }
        .padding(.top, Spacing.l)
    }
}

#Preview("회원정보 수정") {
    NavigationStack {
        AccountInfoView(onSignedOut: {}, onVerifyEmail: {}, onChangePassword: {},
                        onDeleteAccount: {})
    }
    .environment(SessionStore(service: MockAuthService()))
}
