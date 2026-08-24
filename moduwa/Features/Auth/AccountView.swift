import SwiftUI

/// 계정 화면 — 홈 헤더의 메뉴에서 들어온다.
///
/// 로그인 상태면 계정과 로그아웃을, 아니면 로그인·가입으로 가는 길을 보여 준다.
/// 로그아웃하면 **저장 탭·플랜 탭이 비어야 한다** — 계정 데이터는 서버에 남고 다시 로그인하면
/// 돌아오지만, 로그아웃한 기기에 남아 보이면 안 된다(`SessionStore.onSignedOut`).
struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    private enum Route: Hashable { case signIn, signUp, resetPassword, verifyEmail, accessProfile }

    @State private var path: [Route] = []
    @State private var notice: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    if let account = session.account {
                        signedIn(account)
                    } else {
                        signedOut
                        // 로그인하지 않아도 고칠 수 있다 — 이 값은 기기에 남았다가
                        //  가입할 때 계정으로 올라간다(`OnboardingProfileStore`).
                        accessProfileBlock(features: session.accessFeatures)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, Spacing.xxl)
            }
            .background(.white)
            .navigationTitle("내 계정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .font(.notoSans(15, .medium))
                        .foregroundStyle(.textSecondary)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .signIn:
                    SignInView(
                        reason: notice,
                        onSignedIn: { path.removeAll() },
                        onSignUp: { path.append(.signUp) },
                        onForgotPassword: { path.append(.resetPassword) }
                    )
                case .signUp:
                    SignUpView(
                        onSignedUp: { path = [.verifyEmail] },
                        onSocialSignedIn: { path.removeAll() },
                        onSignIn: { path = [.signIn] }
                    )
                case .resetPassword:
                    PasswordResetView { _ in
                        notice = "비밀번호를 바꿨어요. 새 비밀번호로 로그인해 주세요."
                        path = [.signIn]
                    }
                case .verifyEmail:
                    EmailVerifyView { path.removeAll() }
                        .navigationBarBackButtonHidden(true)
                case .accessProfile:
                    AccessibilityProfileEditView(current: session.accessFeatures)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - 로그인 상태

    private func signedIn(_ account: Account) -> some View {
        VStack(spacing: Spacing.xl) {
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
                    Image(systemName: account.emailVerified ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(account.emailVerified ? .deepGreen : .textSecondary)
                    Text(account.emailVerified ? "이메일 인증 완료" : "이메일 인증 전")
                        .font(.notoSans(13, .medium))
                        .foregroundStyle(account.emailVerified ? .deepGreen : .textSecondary)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
            .accessibilityElement(children: .combine)

            accessProfileBlock(features: account.accessFeatures)

            if !account.emailVerified, account.email != nil {
                AuthPrimaryButton(title: "이메일 인증하기") { path.append(.verifyEmail) }
            }

            signOutSection
        }
    }

    /// 무장애 요소 블록. **로그인 여부와 무관하게** 같은 자리에 같은 모양으로 둔다 —
    /// 비로그인이면 기기에 저장된 온보딩 값이고, 그 값도 홈 추천을 좁히는 데 쓰인다.
    /// 고른 것이 없어도 그린다: 없을 때야말로 고르러 갈 길이 필요하다.
    private func accessProfileBlock(features: [AccessibilityFeature]) -> some View {
            Button { path.append(.accessProfile) } label: {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Text("내가 필요한 접근성")
                            .font(.notoSans(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(.textSecondary)
                        Spacer(minLength: 0)
                        Text(features.isEmpty ? "고르기" : "고치기")
                            .font(.notoSans(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(.deepGreen)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.deepGreen)
                    }

                    if features.isEmpty {
                        Text("아직 고른 항목이 없어요. 고르면 홈에서 맞는 곳을 먼저 보여드려요.")
                            .font(.notoSans(13))
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // 라벨을 펼친 상태로 둔다 — 여기서는 아이콘만으로 무엇인지 알기 어렵고,
                        //  프로필은 "무엇이 저장돼 있는지"를 읽는 자리다.
                        FlowLayout {
                            ForEach(features, id: \.self) { feature in
                                AccessibilityBadge(feature: feature, initiallyExpanded: true)
                                    // 카드 전체가 버튼이라 뱃지가 탭을 가로채면 안 된다.
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("무장애 요소를 고치는 화면으로 이동합니다")
    }

    /// 로그아웃 + 무엇이 남는지 알려 주는 한 줄.
    ///
    /// 확인창을 두지 않는다.
    /// ① **되돌릴 수 있는 동작이다.** 계정과 데이터는 서버에 남고 다시 로그인하면 돌아온다.
    ///    이 코드베이스가 확인을 받는 것은 플랜 삭제처럼 **되돌릴 수 없는** 일뿐이다.
    /// ② 시트 안에서 시스템 확인창(`alert`·`confirmationDialog`)이 **버튼 동작을 잃는 것을
    ///    실측했다**(2026-08-21: 창은 뜨고 닫히는데 로그아웃이 실행되지 않았다).
    ///    눌러도 아무 일이 없는 버튼보다, 무엇이 남는지 아래 한 줄로 알려 주고 바로
    ///    로그아웃하는 편이 정직하다.
    private var signOutSection: some View {
            VStack(spacing: Spacing.s) {
                Button {
                    Task {
                        await session.signOut()
                        UIAccessibility.post(notification: .announcement, argument: "로그아웃했어요")
                    }
                } label: {
                    Text("로그아웃")
                        .font(.notoSans(15, .medium))
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Capsule().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityHint("저장한 장소와 플랜은 서버에 남고, 다시 로그인하면 돌아옵니다")

                Text("저장한 장소와 플랜은 서버에 남아 있어요. 다시 로그인하면 그대로 돌아옵니다.")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
    }

    // MARK: - 비로그인 상태

    private var signedOut: some View {
        VStack(spacing: Spacing.xl) {
            AuthHeader(
                title: "로그인하면 더 쓸 수 있어요",
                subtitle: "장소 찾기와 후기 읽기는 로그인 없이도 됩니다. 글쓰기·저장·플랜은 계정이 필요해요 — 기기를 바꿔도 따라오게 하려고요."
            )

            if let notice {
                AuthErrorLine(message: notice)
            }

            VStack(spacing: Spacing.m) {
                AuthPrimaryButton(title: "로그인") { path.append(.signIn) }

                Button { path.append(.signUp) } label: {
                    Text("가입하기")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Capsule().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("로그인 상태") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            AccountView()
                .environment(SessionStore(service: MockAuthService()))
        }
}
