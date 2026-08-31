import SwiftUI

/// 후기 신고 — 사유를 고르고 필요하면 설명을 덧붙여 운영자에게 알린다.
///
/// **글을 감추지 않는다.** 신고는 운영자에게 알리는 일이고, 앱이 곧바로 숨기면 "신고를 누르면
/// 남의 글이 사라지는" 길이 된다. 그래서 보내고 나면 "접수됐다"만 말한다.
///
/// 시안이 없다. 앱의 다른 시트(로그인 계열 폼 · `AccessibilityChoiceRow` 톤)를 따랐다.
struct ReviewReportSheet: View {
    let reviewId: Int
    /// 신고한 뒤 호출부가 알려 줄 것이 있으면(목록 배지 등) 쓴다. 지금은 안내만 띄운다.
    var onReported: (() -> Void)? = nil

    @Environment(\.feedService) private var feedService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var reason: ReviewReportReason?
    @State private var detail = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var isDone = false

    private static let detailLimit = 300

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    AuthHeader(
                        title: "이 후기를 신고할까요?",
                        subtitle: "확인 후 조치돼요. 신고했다고 글이 바로 사라지지는 않아요."
                    )

                    reasons

                    // 사유를 고른 뒤에만 묻는다 — 무엇에 대한 설명인지 정해지기 전에 입력칸을
                    //  먼저 내밀면 무엇을 써야 할지 알 수 없다.
                    if reason != nil { detailField }

                    AuthErrorLine(message: errorMessage)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, Spacing.xl)
            }
            .background(.white)
            .safeAreaInset(edge: .bottom) { submitBar }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.textPrimary)
                }
            }
            .alert("신고를 접수했어요", isPresented: $isDone) {
                Button("확인") { dismiss() }
            } message: {
                Text("확인 후 조치할게요. 알려 주셔서 고마워요.")
            }
        }
    }

    private var reasons: some View {
        VStack(spacing: 0) {
            ForEach(ReviewReportReason.allCases) { item in
                Button {
                    withoutAnimation { reason = item }
                } label: {
                    HStack(spacing: Spacing.m) {
                        Text(item.label)
                            .font(.notoSans(15, .medium, relativeTo: .body))
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 선택을 색만으로 전하지 않는다 — 체크 글리프가 함께 들어온다.
                        Image(systemName: reason == item ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(reason == item ? Color.deepGreen : Color.iconGray)
                    }
                    .padding(.vertical, Spacing.m)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(reason == item ? [.isButton, .isSelected] : .isButton)

                if item != ReviewReportReason.allCases.last {
                    Rectangle().fill(Color.cardStroke).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
    }

    private var detailField: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("더 알려 주실 것이 있나요? (선택)")
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)

            TextEditor(text: $detail)
                .font(.notoSans(15, relativeTo: .body))
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(Spacing.m)
                .background(RoundedRectangle(cornerRadius: Radius.badge).fill(Color.photoPlaceholder))
                .onChange(of: detail) { _, new in
                    if new.count > Self.detailLimit { detail = String(new.prefix(Self.detailLimit)) }
                }
                .accessibilityLabel("신고 상세 설명")
        }
    }

    private var submitBar: some View {
        AuthPrimaryButton(title: "신고하기", isEnabled: reason != nil, isBusy: isSending) {
            Task { await send() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private func send() async {
        guard let reason, !isSending else { return }
        // 신고는 누가 했는지가 남아야 의미가 있다(중복·악용 판단) — 로그인부터 묻는다.
        guard session.requireSignIn(.comment) else { return }

        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await feedService.reportReview(
                reviewId: reviewId, reason: reason,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
            onReported?()
            isDone = true
            UIAccessibility.post(notification: .announcement, argument: "신고를 접수했어요")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "신고를 보내지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview("후기 신고") {
    ReviewReportSheet(reviewId: 1)
        .environment(SessionStore(service: MockAuthService()))
}
