import SwiftUI

/// 개인 데이터 목록이 비로그인일 때 그리는 자리 — 플랜·일정·저장 탭이 함께 쓴다.
///
/// **오류로 그리지 않는다.** 서버가 401 을 주는 것은 맞지만 사용자가 뭘 잘못한 게 아니고,
/// "불러오지 못했어요 · 다시 시도"를 띄우면 눌러도 영원히 같은 결과다 —
/// 해야 할 일이 로그인이라는 사실을 말해 줘야 한다.
struct SignInPromptView: View {
    let title: String
    let message: String
    /// 로그인 시트 상단에 남길 이유.
    let prompt: AuthPrompt

    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: Spacing.m) {
            Text(title)
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.notoSans(14, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            AuthPrimaryButton(title: "로그인") { session.prompt = prompt }
                .frame(maxWidth: 234)
                .padding(.top, Spacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .accessibilityElement(children: .contain)
    }
}

#Preview("비로그인 목록") {
    SignInPromptView(
        title: "로그인하면 플랜을 볼 수 있어요",
        message: "만든 플랜은 계정에 저장돼요. 기기를 바꿔도 그대로 따라옵니다.",
        prompt: .plan
    )
    .environment(SessionStore(service: MockAuthService()))
}
