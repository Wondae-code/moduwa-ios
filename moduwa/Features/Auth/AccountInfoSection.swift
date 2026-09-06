import SwiftUI

/// 계정을 다루는 덩어리 — 이름·이메일·인증 상태, 비밀번호 변경, 로그아웃, 회원 탈퇴.
///
/// **화면이 아니라 섹션이다**(2026-09-07 QA #2). 예전에는 "회원정보 수정" 이라는 별도 화면이었고
/// `설정 → 프로필 편집 → 회원정보 수정` 3단이었다 — 로그아웃 한 번 하려고 세 번 들어가야 했다.
/// 프로필 편집 안으로 들여 2단으로 줄였다. 파일을 따로 두는 이유는 `ProfileEditView` 가 이미
/// 360줄이라서다(사진 고르기·닉네임 검사·저장이 다 거기 있다).
///
/// **로그아웃이 여기 있다.** 시안(821:103)에는 로그아웃 줄이 없고 "비로그인시" 화면도 없어서,
/// 계정 자체를 다루는 이 덩어리 안에 두었다 — 이메일 인증과 같은 자리가 맞다.
///
/// 로그아웃하면 **저장 탭·플랜 탭이 비어야 한다** — 계정 데이터는 서버에 남고 다시 로그인하면
/// 돌아오지만, 로그아웃한 기기에 남아 보이면 안 된다(`SessionStore.onSignedOut`).
struct AccountInfoSection: View {
    /// 이메일 인증 화면으로. **경로는 감싸는 화면이 쥔다** — 밀어 넣는 스택이 하나여야
    /// 뒤로 가기가 어긋나지 않는다(`ProfileEditView.SubRoute`).
    var onVerifyEmail: () -> Void
    var onChangePassword: () -> Void
    /// 회원 탈퇴 화면으로. **앱스토어 심사 필수**(5.1.1(v)) — 계정을 만들 수 있는 앱은 앱 안에서
    /// 계정 삭제도 제공해야 한다. 로그아웃과 같은 자리에 두지만 아래로, 톤도 다르게 둔다.
    var onDeleteAccount: () -> Void = {}

    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if let account = session.account {
                emailBlock(account)

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

    /// 이메일과 인증 상태.
    ///
    /// ⚠️ **닉네임을 여기 다시 쓰지 않는다**(2026-09-07 요청). 예전에는 이름·이메일·인증을
    /// 한 카드에 담았는데, 바로 위가 닉네임 **입력 칸**이라 화면이 "닉네임 → 닉네임 → 이메일"
    /// 로 읽혔다. 한 값은 한 번만 나온다 — 위에서 아래로 **닉네임 · 이메일 · 비밀번호 변경 ·
    /// 로그아웃 · 회원 탈퇴**, 각자 한 줄씩.
    ///
    /// 라벨(14) + 간격 7 은 위 닉네임 칸(`AuthField`)과 같은 규격이다 — 나란히 서는 두 값이
    /// 다른 규격이면 한쪽이 잘못 만들어진 것으로 보인다. 이메일은 **고칠 수 없는 값**이라
    /// 입력 칸이 아니라 읽기 전용 상자다.
    @ViewBuilder
    private func emailBlock(_ account: Account) -> some View {
        if let email = account.email {
            VStack(alignment: .leading, spacing: 7) {
                Text("이메일")
                    .font(.notoSans(14, relativeTo: .subheadline))
                    .foregroundStyle(.textPrimary)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(email)
                        .font(.notoSans(16, relativeTo: .body))
                        .foregroundStyle(.textPrimary)

                    HStack(spacing: 6) {
                        // 색만으로 알리지 않는다 — 아이콘 모양과 글자가 함께 말한다.
                        Image(systemName: account.emailVerified
                              ? "checkmark.seal.fill" : "exclamationmark.circle")
                            .font(.system(size: 14))
                        Text(account.emailVerified ? "이메일 인증 완료" : "이메일 인증 전")
                            .font(.notoSans(13, .medium, relativeTo: .footnote))
                    }
                    .foregroundStyle(account.emailVerified ? Color.deepGreen : .textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.l)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
                .accessibilityElement(children: .combine)
            }
        }
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
                    // 화면을 닫는 일은 감싸는 쪽이 한다 — `ProfileEditView` 가
                    //  `onChange(of: session.account == nil)` 으로 보고 있다.
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

#Preview("계정 섹션") {
    ScrollView {
        AccountInfoSection(onVerifyEmail: {}, onChangePassword: {}, onDeleteAccount: {})
            .padding(.horizontal, AuthMetrics.horizontal)
            .padding(.vertical, Spacing.xl)
    }
    .background(.white)
    .environment(SessionStore(service: MockAuthService()))
}
