import SwiftUI

/// 회원 탈퇴 — 계정을 지운다. **되돌릴 수 없다.**
///
/// 앱스토어 심사 필수 항목이다(5.1.1(v): 계정을 만들 수 있는 앱은 앱 안에서 계정 삭제도
/// 제공해야 한다). 그래서 "회원정보 수정" 안에 둔다 — 계정을 다루는 다른 것들과 같은 자리다.
///
/// **확인창(`alert`)이 아니라 별도 화면인 이유**: ① 이 스택은 시트 안에 있고, 시트 안 확인창이
/// 버튼 동작을 잃는 것을 실측했다(`AccountInfoView.signOutSection` 주석 — 그래서 로그아웃은
/// 확인을 받지 않는다). ② 무엇이 지워지고 무엇이 남는지 **읽을 자리가 필요하다** — 익명화
/// 정책을 한 줄로 설명하지 않으면 사용자는 자기 글이 어떻게 되는지 모른 채 누른다.
struct AccountDeleteView: View {
    /// 삭제가 끝났다. 부르는 쪽이 화면을 정리한다(설정까지 닫고 비로그인 상태로).
    var onDeleted: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirming = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                AuthHeader(
                    title: "회원 탈퇴",
                    subtitle: "탈퇴하면 계정과 로그인 정보가 사라져요. 되돌릴 수 없어요."
                )

                what
                stays

                AuthErrorLine(message: errorMessage)
            }
            .padding(.horizontal, AuthMetrics.horizontal)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) { deleteBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // ⚠️ 확인창은 **바깥 뷰**에 붙인다(플랜 상세에서 실측한 함정). 그리고 이 화면 자체가
        //  이미 설명이므로, 창은 마지막 되돌릴 수 없음만 다시 묻는다.
        .confirmationDialog("정말 탈퇴할까요?", isPresented: $isConfirming, titleVisibility: .visible) {
            Button("탈퇴하기", role: .destructive) { Task { await delete() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌릴 수 없어요. 같은 계정으로 다시 가입하면 새 계정이 돼요.")
        }
    }

    private var what: some View {
        section(title: "지워지는 것", items: [
            "로그인 정보 — 이메일·비밀번호, 애플·구글·카카오 연결",
            "프로필 — 닉네임·사진·무장애 정보",
            "저장한 장소와 좋아요",
            "알림 설정(이 기기로 오던 알림도 멈춰요)",
        ])
    }

    /// 익명화 정책을 **먼저** 말한다. 이걸 모르고 누르면 "내 글이 그대로 있다" 로 놀라게 된다.
    private var stays: some View {
        section(title: "남는 것", items: [
            "내가 쓴 게시글·후기·댓글 — 글은 남고 이름이 ‘탈퇴한 사용자’로 바뀌어요",
            "함께 쓰던 플랜 — 다른 참여자가 있으면 그분에게 넘어가고, 없으면 지워져요",
        ])
    }

    private func section(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(.textPrimary)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.notoSans(14, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
    }

    /// 되돌릴 수 없는 동작이라 브랜드 라임을 쓰지 않는다 — 앱의 다른 CTA 와 같은 색이면
    /// 손이 먼저 간다. 테두리만 두고 글자를 오류색으로 둔다.
    private var deleteBar: some View {
        Button {
            isConfirming = true
        } label: {
            ZStack {
                Text("회원 탈퇴")
                    .font(.notoSans(16, .bold, relativeTo: .headline))
                    .foregroundStyle(.errorRed)
                    .opacity(isDeleting ? 0 : 1)
                if isDeleting { ProgressView().tint(.errorRed) }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AuthMetrics.buttonHeight)
            .background(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.errorRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .padding(.horizontal, AuthMetrics.horizontal)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .accessibilityLabel(isDeleting ? "탈퇴 처리 중" : "회원 탈퇴")
    }

    private func delete() async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await session.deleteAccount()
            UIAccessibility.post(notification: .announcement, argument: "탈퇴했어요")
            onDeleted()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "탈퇴하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isDeleting = false
    }
}

#Preview("회원 탈퇴") {
    NavigationStack {
        AccountDeleteView(onDeleted: {})
            .environment(SessionStore(service: MockAuthService()))
    }
}
