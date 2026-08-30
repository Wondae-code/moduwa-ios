import SwiftUI

/// 초대 코드 수동 입력 — 유니버설 링크가 앱을 못 열 때(카톡 인앱 웹뷰 등)의 폴백.
///
/// 서버는 하이픈·소문자가 섞여도 받아 주므로(`wkq3-m8dz` OK) 입력을 억지로 정규화하지 않는다 —
/// 앞뒤 공백만 턴다. 수락은 `planService.acceptInvite` 로 바로 하고, 성공하면 호출부가 목록을
/// 갱신한다.
struct PlanJoinByCodeView: View {
    /// 수락 성공 — 호출부가 목록을 갱신하고 안내를 띄운다.
    var onJoined: (InviteAcceptance) -> Void

    @Environment(\.planService) private var planService
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var trimmed: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.l) {
                AuthHeader(
                    title: "초대 코드로 참여",
                    subtitle: "받은 초대 링크의 코드를 입력하면 플랜에 함께할 수 있어요."
                )

                TextField("초대 코드", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await join() } }
                    .font(.notoSans(18, .medium))
                    .padding(Spacing.l)
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.notoSans(13))
                        .foregroundStyle(.errorRed)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .background(.white)
            .safeAreaInset(edge: .bottom) {
                AuthPrimaryButton(title: "참여하기", isEnabled: !trimmed.isEmpty, isBusy: isWorking) {
                    Task { await join() }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, Spacing.m)
                .background(.white)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.textPrimary)
                }
            }
        }
    }

    private func join() async {
        guard !trimmed.isEmpty, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        do {
            let result = try await planService.acceptInvite(code: trimmed)
            onJoined(result)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "초대를 수락하지 못했어요."
        }
        isWorking = false
    }
}

#Preview("코드 참여") {
    PlanJoinByCodeView(onJoined: { _ in })
        .environment(\.planService, MockPlanService())
}
