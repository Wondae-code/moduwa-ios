import SwiftUI

/// 여행 동반자 수정 — 플랜 카드 ⋮ 의 "팀 수정"(시안 553:133).
///
/// 새 플랜 플로우 1/6에서 고른 값을 나중에 다시 손보는 자리다. 그래서 고르는 화면(`PlanPartyStep`)을
/// 그대로 쓴다 — 같은 값을 고르는데 화면이 둘로 갈리면 한쪽만 항목이 늘어나는 일이 생긴다.
///
/// 저장은 **완료를 눌러야** 일어난다. 칩을 눌러 보다가 되돌리고 싶을 때 나갈 길이 있어야 한다.
struct PlanPartyEditView: View {
    let currentParty: TravelParty
    /// 바뀐 팀을 저장한다. **저장이 끝날 때까지 기다린다** — 시트를 먼저 닫고 뒤에서 저장하면
    /// 실패했을 때 방금 고른 것이 어디에도 남지 않는다(`PlanMemoComposeView` 와 같은 규칙).
    var onSave: (TravelParty) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var party: TravelParty
    @State private var isSaving = false
    @State private var saveError: String?

    init(currentParty: TravelParty, onSave: @escaping (TravelParty) async throws -> Void) {
        self.currentParty = currentParty
        self.onSave = onSave
        _party = State(initialValue: currentParty)
    }

    /// 아무것도 안 고른 상태로도 저장할 수 있다 — 플로우 1/6 도 건너뛸 수 있어서
    /// "팀 정보 없음"은 정상적인 값이다. 바뀐 게 없을 때만 막는다.
    private var canSubmit: Bool { party != currentParty }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                PlanPartyStep(party: $party)
                    .padding(.top, 28)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { submitBar }
    }

    private var headerBar: some View {
        Text("팀 수정")
            .font(.notoSans(18, .bold, relativeTo: .headline))
            .tracking(-0.4)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityAddTraits(.isHeader)
    }

    private var submitBar: some View {
        VStack(spacing: 8) {
            if let saveError {
                Text(saveError)
                    .font(.notoSans(13))
                    .foregroundStyle(.deepGreen)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !canSubmit {
                Text("바뀐 내용이 없어요")
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Task { await save() }
            } label: {
                ZStack {
                    Text("완료")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(canSubmit ? .textPrimary : .textSecondary)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.textPrimary) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Capsule().fill(canSubmit ? Color.moduwaGreen : Color.photoPlaceholder))
                .shadow(color: Color(hex: 0x9ACA10).opacity(canSubmit ? 0.3 : 0), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSaving)
            .accessibilityLabel(isSaving ? "팀 저장 중" : "팀 저장하기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    private func save() async {
        guard canSubmit else { return }
        isSaving = true
        saveError = nil
        do {
            try await onSave(party)
            UIAccessibility.post(notification: .announcement, argument: "팀 정보를 바꿨어요")
            dismiss()
        } catch {
            saveError = (error as? PlanServiceError)?.errorDescription
                ?? "팀 정보를 저장하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            UIAccessibility.post(notification: .announcement, argument: saveError ?? "")
        }
        isSaving = false
    }
}

#Preview("팀 수정") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanPartyEditView(currentParty: MockData.upcomingGyeongju.party) { _ in }
        }
}
