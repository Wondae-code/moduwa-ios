import SwiftUI

/// **동의 기록 없이 무장애 항목을 갖고 있는 계정에게 다시 묻는 화면**(서버 050).
///
/// 동의 절차가 생기기 전에 가입한 사람들이다. 법은 동의받은 사실을 처리자가 입증하도록 하므로,
/// 기록이 없으면 "동의 없이 수집했다" 는 주장에 반증할 수단이 없다. 그래서 조용히 지우지도,
/// 조용히 두지도 않고 **묻는다** — 둘 다 사용자를 대신해 결정하는 것이다.
///
/// 답이 둘뿐이라 버튼도 둘이다. "나중에" 를 두는 이유: 이 창이 앱을 처음 켠 사람의 길을
/// 막아서는 안 된다. 답하지 않으면 서버의 `needsSensitiveConsent` 가 그대로 남아 다음에 다시 뜬다.
struct SensitiveConsentPrompt: View {
    /// 지금 계정에 저장돼 있는 항목. 무엇에 대한 동의인지 눈으로 보여 준다 —
    /// "민감정보에 동의하시겠습니까" 만 물으면 무엇을 동의하는지 알 수 없다.
    let features: [AccessibilityFeature]
    /// 동의 — 같은 값을 동의와 함께 다시 저장한다(서버가 기록을 남긴다). 성공했으면 true.
    var onAgree: () async -> Bool
    /// 거부 — 항목을 지운다(빈 배열이 철회다). 성공했으면 true.
    var onDecline: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isBusy = false
    @State private var isShowingNotice = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    AuthHeader(
                        title: "무장애 정보 동의를 확인해요",
                        subtitle: "이 항목은 건강·장애에 관한 민감정보예요. 예전에 등록하신 값이 남아 있는데, 동의를 받은 기록이 없어서 다시 확인하고 있어요."
                    )

                    // 무엇에 대한 동의인지 — 값을 보여 주지 않고 묻는 것은 동의가 아니다.
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 10) {
                                Image(feature.iconName)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(.deepGreen)
                                Text(feature.label)
                                    .font(.notoSans(15, .medium))
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.l)
                    .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

                    Button("민감정보 수집·이용 안내 보기") { isShowingNotice = true }
                        .font(.notoSans(14, .bold))
                        .foregroundStyle(.deepGreen)
                        .frame(minHeight: 44)

                    Text("동의하지 않으셔도 됩니다. 그때는 이 항목을 지우고, 맞춤 추천 없이 서비스를 그대로 이용하실 수 있어요.")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    AuthErrorLine(message: errorMessage)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, Spacing.xl)
            }
            .background(.white)
            .safeAreaInset(edge: .bottom) { buttons }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // 답을 강요하지 않는다 — 다음에 다시 뜬다.
                    Button("나중에") { dismiss() }
                        .font(.notoSans(15))
                        .foregroundStyle(.textSecondary)
                        .disabled(isBusy)
                }
            }
            .legalDocumentSheet(noticeBinding)
        }
        .interactiveDismissDisabled(isBusy)
    }

    private var noticeBinding: Binding<LegalDocument?> {
        Binding(get: { isShowingNotice ? .sensitive : nil },
                set: { isShowingNotice = $0 != nil })
    }

    private var buttons: some View {
        VStack(spacing: Spacing.s) {
            AuthPrimaryButton(title: "동의하고 계속 쓰기", isEnabled: !isBusy, isBusy: isBusy) {
                Task { await run(onAgree, failure: "동의를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.") }
            }

            // 지우기는 되돌릴 수 없으니 라임 CTA 로 두지 않는다 — 무게가 다른 두 답이다.
            Button {
                Task { await run(onDecline, failure: "항목을 지우지 못했어요. 잠시 후 다시 시도해 주세요.") }
            } label: {
                Text("동의하지 않고 항목 지우기")
                    .font(.notoSans(15, .bold))
                    .foregroundStyle(.errorRed)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 51)
                    .background(RoundedRectangle(cornerRadius: 18).stroke(Color.errorRed, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
    }

    /// ⚠️ **성공했을 때 이 화면이 스스로 닫지 않는다.** 계정 값이 바뀌면 호출부가
    /// `needsSensitiveConsent` 를 다시 보고 닫는다 — 여기서 닫으면 저장이 실패했는데도
    /// 닫히는 경우가 생기고, 그러면 사용자는 답한 줄 알지만 기록은 없다.
    private func run(_ action: () async -> Bool, failure: String) async {
        isBusy = true
        errorMessage = nil
        let succeeded = await action()
        isBusy = false
        if !succeeded { errorMessage = failure }
    }
}
