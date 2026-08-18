import SwiftUI

/// 일정에 메모 한 줄 붙이기 — 플랜 상세 하단 "메모 추가"(시안 519:810 / 519:92).
///
/// **시안 미확보(2026-08-16 피그마 전수 확인)** — 상세 시안에는 회색 알약 버튼 자리만 있고
/// 누른 뒤의 화면이 파일 어디에도 없다. 장소 추가와 달리 참고 스샷(519:1178)조차 없어
/// 후기 작성(`ReviewComposeView`)의 톤을 그대로 따랐다 — 흰 시트, 좌우 24, 회색 입력 박스,
/// 라임 캡슐 CTA, 실패 사유를 버튼 위에 얹는 배치.
///
/// **어느 Day에 붙일지는 이 화면에서 묻지 않는다**(2026-08-16 사용자 지시). 상세가 하루씩만
///  보여 주게 되면서 "지금 보고 있는 날"이 곧 붙일 날이 됐다 — 화면 안에서 또 고르게 하면
///  방금 넘겨 온 날짜를 한 번 더 확인시키는 셈이라 되레 어긋난다. 대신 어느 날에 들어가는지를
///  맨 위에 되짚어 둔다(`targetDayRow`) — 몰래 정한 것처럼 보이지 않게.
struct PlanMemoComposeView: View {
    /// 메모가 들어갈 날. 서버에 이미 있는 날일 수도 있고, 아직 일정이 없어 여행 기간에서
    /// 만들어 낸 후보일 수도 있다(`Plan.dayCandidates`) — 여기서는 구분하지 않는다.
    let day: PlanDay
    /// 여행 기간에서 이 날이 몇 번째인지("DAY 2"). 날짜만으로는 알 수 없어 상세가 넘겨 준다.
    let dayNumber: Int
    /// 이 날에 메모를 붙인다. 그 날이 실제로 서버에 있는지는 호출부가 판단한다.
    ///
    /// **저장이 끝날 때까지 기다린다** — 시트를 먼저 닫고 뒤에서 저장하면 실패했을 때
    /// 방금 쓴 글이 어디에도 남지 않는다(`PlanEditView.onDone`과 같은 규칙).
    var onAdd: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSaving = false
    /// 저장 실패 사유. 서버가 한국어로 알려 주면 그대로 담는다.
    @State private var saveError: String?
    @FocusState private var isTextFocused: Bool

    /// 타임라인의 회색 메모 카드가 한 화면을 삼키지 않을 만큼. 서버는 길이를 제한하지 않으므로
    /// (`plan_items.memo_text`는 그냥 text) 이 값은 순전히 화면 쪽 판단이다.
    static let textLimit = 200

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { !trimmed.isEmpty }

    /// 비활성 상태를 회색이라는 **색만으로** 전달하지 않기 위한 문장 (`ReviewComposeView`와 같은 규칙).
    private var missingHint: String? {
        trimmed.isEmpty ? "메모를 입력해 주세요" : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    targetDayRow
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    memoSection
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                }
                .padding(.bottom, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom) { submitBar }
        // 고를 것이 없으니 열자마자 할 일은 쓰는 것뿐이다 — 키보드를 바로 올린다.
        .onAppear { isTextFocused = true }
    }

    // MARK: - 헤더

    /// 후기 작성과 같게 닫기 버튼이 없다 — 시트의 스와이프 닫기에 맡기고
    /// 그게 가능하다는 걸 드래그 인디케이터로 보인다(VoiceOver는 스크럽 제스처로 닫는다).
    private var headerBar: some View {
        Color.clear
            .frame(height: 22)
            .background(.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.cardStroke).frame(height: 1)
            }
            .accessibilityHidden(true)
    }

    // MARK: - 들어갈 날

    /// 어느 날에 들어가는지 되짚는 줄. 고르는 자리가 아니라 **알리는 자리**다 —
    /// 날짜는 상세에서 이미 정해져 왔고, 여기서 바꿀 수 있는 것처럼 보이면 안 된다.
    private var targetDayRow: some View {
        Text("\(day.title(number: dayNumber))에 추가돼요")
            .font(.notoSans(14, .medium))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
    }

    // MARK: - 메모 본문

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("메모")

            ZStack(alignment: .topLeading) {
                // TextEditor는 플레이스홀더를 지원하지 않아 겹쳐 그린다.
                // 위치 상수(top 8 / leading 5)는 TextEditor 내부 기본 인셋에 맞춘 값이다.
                if text.isEmpty {
                    Text("예매 시간, 주차 자리, 챙길 것처럼 그날 기억해야 할 것을 적어 두세요.")
                        .font(.notoSans(15))
                        .foregroundStyle(.iconGray)
                        .lineSpacing(4)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $text)
                    .font(.notoSans(15))
                    .foregroundStyle(.textPrimary)
                    .tint(.deepGreen)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .focused($isTextFocused)
                    .onChange(of: text) {
                        if text.count > Self.textLimit {
                            text = String(text.prefix(Self.textLimit))
                        }
                    }
                    .accessibilityLabel("메모 내용")
                    .accessibilityHint("최대 \(Self.textLimit)자까지 쓸 수 있어요")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

            Text("\(text.count) / \(Self.textLimit)")
                .font(.notoSans(13, .medium))
                .foregroundStyle(text.count >= Self.textLimit ? .deepGreen : .textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(text.count)자 입력, 최대 \(Self.textLimit)자")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(16, .bold, relativeTo: .headline))
            .tracking(-0.4)
            .foregroundStyle(Color.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 하단

    private var submitBar: some View {
        VStack(spacing: 8) {
            // 실패 사유가 있으면 그것을 먼저 알린다. 없을 때만 "무엇이 비었는지" 안내를 띄운다.
            if let saveError {
                Text(saveError)
                    .font(.notoSans(13))
                    .foregroundStyle(.deepGreen)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
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
                    Text("추가하기")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(canSubmit ? .textPrimary : .textSecondary)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.textPrimary) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Capsule().fill(canSubmit ? Color.moduwaGreen : Color.photoPlaceholder))
                // 라임 CTA 그림자는 HeroCard·후기 작성과 같은 값 (활성일 때만)
                .shadow(color: Color(hex: 0x9ACA10).opacity(canSubmit ? 0.3 : 0), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSaving)
            .accessibilityLabel(isSaving ? "메모 추가 중" : "메모 추가하기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 저장

    private func save() async {
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveError = nil
        do {
            try await onAdd(trimmed)
            // 시트가 곧 닫히므로 추가됐다는 사실이 시각적으로는 타임라인 말고 남지 않는다.
            UIAccessibility.post(notification: .announcement, argument: "메모를 추가했어요")
            dismiss()
        } catch {
            // 서버가 사유를 한국어로 준 경우만 그대로 쓴다. URLError 등 시스템 오류의 원문은
            // 사용자가 할 수 있는 일을 알려 주지 못한다 (`PlanEditView.save`와 같은 규칙).
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "메모를 추가하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isSaving = false
    }
}

#Preview("메모 쓰기") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanMemoComposeView(day: MockData.upcomingGyeongju.days[0], dayNumber: 1) { _ in }
        }
}

#Preview("저장 실패") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanMemoComposeView(day: MockData.upcomingGyeongju.days[0], dayNumber: 1) { _ in
                throw PlanServiceError.server(message: "메모를 추가하지 못했어요. (서버 점검 중)")
            }
        }
}
