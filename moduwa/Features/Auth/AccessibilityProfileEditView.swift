import SwiftUI

/// 내 정보 → 무장애 요소 고치기.
///
/// 온보딩에서 한 번 고르고 끝나는 값이 아니다 — 다치거나 회복하거나 아이가 크면 필요한 것이
/// 바뀐다. 온보딩을 건너뛴 사람이 나중에 고르는 길이기도 하다.
///
/// **로그인하지 않아도 고칠 수 있다.** 로그인 상태면 계정에 저장되고(`PATCH /v1/auth/me`)
/// 기기를 바꿔도 따라오며, 아니면 기기에 남았다가 나중에 가입할 때 계정으로 올라간다.
/// 어느 쪽이든 **홈의 추천 목록을 좁히는 조건**이 된다 — 그래서 화면에 그 사실을 적어 둔다.
/// 고른 것이 무엇을 바꾸는지 모르면 사람은 고르지 않는다.
struct AccessibilityProfileEditView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var selection: [AccessibilityFeature]
    @State private var isBusy = false
    @State private var errorMessage: String?

    /// 지금 계정에 저장된 값으로 시작한다.
    init(current: [AccessibilityFeature]) {
        _selection = State(initialValue: current)
    }

    /// 저장할 것이 있는지. 순서가 아니라 **집합**으로 비교한다 —
    /// 껐다 켜서 순서만 달라진 것은 바뀐 것이 아니다.
    private var hasChanges: Bool {
        Set(selection) != Set(session.accessFeatures)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                AuthHeader(
                    title: "내가 필요한 접근성",
                    subtitle: session.account == nil
                        ? "고른 항목에 모두 맞는 곳을 홈에서 먼저 보여드려요. 지금은 이 기기에만 저장되고, 가입하면 계정으로 옮겨져 기기를 바꿔도 따라옵니다."
                        : "고른 항목에 모두 맞는 곳을 홈에서 먼저 보여드려요. 지금 필요한 것이 없으면 모두 해제해도 괜찮아요."
                )

                VStack(spacing: 0) {
                    ForEach(AccessibilityChoiceRow.choices, id: \.self) { feature in
                        AccessibilityChoiceRow(
                            feature: feature,
                            isOn: selection.contains(feature)
                        ) {
                            if selection.contains(feature) {
                                selection.removeAll { $0 == feature }
                            } else {
                                selection.append(feature)
                            }
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

                // 고를 수는 있지만 목록을 좁히지는 못하는 항목이 있다. 숨기지 않고 말해 준다 —
                //  고른 대로 걸러진 줄 알았는데 아니면, 다음에 보이는 목록 전부를 의심하게 된다.
                if selection.contains(.elderlyFriendly) {
                    Text("고령자 친화는 아직 추천을 좁히는 데 쓰이지 않아요. 관광공사 원본에 그 항목이 없어서, 프로필에는 남지만 목록은 다른 조건으로만 걸러져요.")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.badge)
                            .fill(Color.photoPlaceholder))
                }

                // 청각 지원은 원본 데이터가 얇다. 고르고 나서 목록이 비면 앱이 고장난 것처럼
                //  보이므로 미리 알린다(전국 107곳 — 관광지 27·맛집 22·숙소 23·축제 0).
                if selection.contains(.hearingFriendly) {
                    Text("자막·수어 안내가 등록된 곳은 아직 전국 107곳뿐이에요. 목록이 금방 끝날 수 있어요.")
                        .font(.notoSans(13))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.badge)
                            .fill(Color.photoPlaceholder))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, Spacing.xl)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.m) {
            AuthErrorLine(message: errorMessage)

            AuthPrimaryButton(title: "저장", isEnabled: hasChanges, isBusy: isBusy) {
                Task { await save() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private func save() async {
        guard hasChanges, !isBusy else { return }
        isBusy = true
        errorMessage = nil
        do {
            try await session.updateAccessFeatures(selection)
            UIAccessibility.post(notification: .announcement, argument: "저장했어요")
            dismiss()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "저장하지 못했어요. 잠시 후 다시 시도해 주세요."
            errorMessage = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isBusy = false
    }
}

#Preview("무장애 요소 고치기") {
    NavigationStack {
        AccessibilityProfileEditView(current: [.wheelchairAccessible])
    }
    .environment(SessionStore(service: MockAuthService()))
}
