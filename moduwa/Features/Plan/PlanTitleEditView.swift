import SwiftUI

/// 플랜 제목 수정 — 여행 상세 헤더의 연필(시안 519:1195 계열, 코멘트 지시 2026-08-16).
///
/// **시안 없음.** 헤더에 연필 아이콘만 있고 누른 뒤 화면은 피그마에 없다.
/// 메모 추가(`PlanMemoComposeView`)와 같은 틀을 썼다 — 흰 시트, 좌우 24, 회색 입력 상자,
/// 라임 캡슐 CTA, 실패 사유를 버튼 위에.
///
/// 이름 바꾸기는 보통 `alert` + `TextField` 로 하지만 여기서는 시트다 —
/// **저장이 끝날 때까지 화면을 열어 둬야** 실패했을 때 고쳐 쓴 제목이 남는다.
/// alert 는 버튼을 누르는 즉시 닫혀 그럴 수가 없다(`PlanEditView.onDone` 과 같은 규칙).
struct PlanTitleEditView: View {
    let currentTitle: String
    /// 새 제목을 저장한다. 저장이 끝날 때까지 기다린다.
    var onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var isSaving = false
    /// 저장 실패 사유. 서버가 한국어로 알려 주면 그대로 담는다.
    @State private var saveError: String?
    @FocusState private var isFocused: Bool

    /// 목록 카드와 상세 제목이 두 줄을 넘지 않을 만큼. 서버는 길이를 제한하지 않으므로
    /// (`plans.title` 은 그냥 text) 이 값은 순전히 화면 쪽 판단이다.
    static let titleLimit = 40

    init(currentTitle: String, onSave: @escaping (String) async throws -> Void) {
        self.currentTitle = currentTitle
        self.onSave = onSave
        _title = State(initialValue: currentTitle)
    }

    private var trimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 제목이 비면 목록 카드에 아무것도 안 남는다 — 빈 제목은 막는다.
    /// 바뀐 것이 없을 때도 막는다 — 서버를 한 번 갔다 올 이유가 없다.
    private var canSubmit: Bool { !trimmed.isEmpty && trimmed != currentTitle }

    private var missingHint: String? {
        if trimmed.isEmpty { "제목을 입력해 주세요" }
        else if trimmed == currentTitle { "제목이 그대로예요" }
        else { nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            VStack(alignment: .leading, spacing: 10) {
                Text("제목")
                    .font(.notoSans(16, .bold, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                TextField("여행 제목을 입력해 주세요", text: $title, axis: .vertical)
                    .font(.notoSans(15))
                    .foregroundStyle(Color.textPrimary)
                    .tint(.deepGreen)
                    .lineLimit(1...3)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: Radius.card)
                        .fill(Color.photoPlaceholder))
                    .onChange(of: title) {
                        // 줄바꿈은 제목에 들어갈 자리가 없다 — 붙여넣기로 들어오는 것까지 막는다.
                        let flattened = title.replacingOccurrences(of: "\n", with: " ")
                        let capped = String(flattened.prefix(Self.titleLimit))
                        if capped != title { title = capped }
                    }
                    .accessibilityLabel("여행 제목")

                Text("\(title.count) / \(Self.titleLimit)")
                    .font(.notoSans(13, .medium))
                    .foregroundStyle(title.count >= Self.titleLimit ? .deepGreen : .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("\(title.count)자 입력, 최대 \(Self.titleLimit)자")
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer(minLength: 0)
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .presentationDetents([.height(300)])
        .safeAreaInset(edge: .bottom) { submitBar }
        .onAppear { isFocused = true }
    }

    private var headerBar: some View {
        Color.clear
            .frame(height: 22)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityHidden(true)
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
            } else if let missingHint {
                Text(missingHint)
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Task { await save() }
            } label: {
                ZStack {
                    Text("저장")
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
            .accessibilityLabel(isSaving ? "제목 저장 중" : "제목 저장하기")
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
            try await onSave(trimmed)
            UIAccessibility.post(notification: .announcement, argument: "제목을 바꿨어요")
            dismiss()
        } catch {
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "제목을 저장하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isSaving = false
    }
}

#Preview("제목 수정") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanTitleEditView(currentTitle: "가족과 함께하는 경주 여행") { _ in }
        }
}

#Preview("저장 실패") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanTitleEditView(currentTitle: "가족과 함께하는 경주 여행") { _ in
                throw PlanServiceError.server(message: "제목을 저장하지 못했어요. (서버 점검 중)")
            }
        }
}
