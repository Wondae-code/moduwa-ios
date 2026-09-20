import SwiftUI

/// 여행 날짜 수정 — 여행 상세의 날짜 줄을 누르면 열린다.
///
/// **시안 없음.** 제목(`PlanTitleEditView`)·팀(`PlanPartyEditView`)과 같은 틀을 쓴다 —
/// 흰 시트, 헤더 바, 라임 캡슐 CTA, 실패 사유를 버튼 위에. 달력은 새 플랜 3/6 의
/// `PlanDateRangeCalendar` 를 그대로 쓴다(같은 질문에 두 가지 달력을 두지 않는다).
///
/// ## 기간을 줄이면 그 날 일정이 사라진다
///
/// 되돌릴 수 없는 삭제이므로 **저장 전에 무엇이 사라지는지 세어 보여 준다**(2026-09-20 결정).
/// 서버가 대신 잘라 주지 않는다 — `PUT /v1/plans/:planId` 는 `days[]` 를 통째로 받으므로
/// **앱이 계산해서 보낸다.** 그래서 앱이 무엇을 지우는지 정확히 알고 있고, 알면 말할 수 있다.
///
/// 빈 날은 세지 않는다. 날짜만 줄어드는 것은 잃는 것이 없어 물어볼 일이 아니다.
struct PlanDateEditView: View {
    let plan: Plan
    /// 다른 플랜이 잡아 둔 날짜. **이 플랜 자신의 기간은 빼고** 넘겨야 한다 —
    /// 안 빼면 지금 잡혀 있는 날이 "이미 찼다" 로 막혀 제 날짜를 다시 고를 수 없다.
    var busyRanges: [ClosedRange<Date>] = []
    /// 새 기간과, 그 기간 밖으로 밀려난 날을 지운 `days` 를 저장한다.
    var onSave: (_ startDate: Date, _ endDate: Date, _ days: [PlanDay]) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var isSaving = false
    @State private var saveError: String?
    /// 잃을 것이 있을 때 띄우는 확인 창. `nil` 이면 닫혀 있다.
    @State private var confirming: Loss?

    private let calendar = Calendar.current

    init(plan: Plan,
         busyRanges: [ClosedRange<Date>] = [],
         onSave: @escaping (Date, Date, [PlanDay]) async throws -> Void) {
        self.plan = plan
        self.busyRanges = busyRanges
        self.onSave = onSave
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate)
    }

    // MARK: 무엇이 사라지나

    /// 새 기간 밖으로 밀려나면서 **내용이 있는** 날들.
    struct Loss: Equatable {
        var days: [PlanDay]

        var dayCount: Int { days.count }
        var stopCount: Int { days.reduce(0) { $0 + $1.stops.count } }
        var memoCount: Int { days.reduce(0) { $0 + ($1.items.count - $1.stops.count) } }

        /// "2일치 · 장소 5곳과 메모 1개" — 숫자로 말한다. "일부 일정" 같은 말로는
        /// 무엇을 잃는지 가늠할 수 없어 사용자가 확인 버튼을 누를 근거가 없다.
        var summary: String {
            var parts: [String] = []
            if stopCount > 0 { parts.append("장소 \(stopCount)곳") }
            if memoCount > 0 { parts.append("메모 \(memoCount)개") }
            let what = parts.isEmpty ? "담긴 것" : parts.joined(separator: "과 ")
            return "\(dayCount)일치 · \(what)"
        }
    }

    /// 새 기간 밖으로 밀려나는 날. **빈 날은 빼고** 돌려준다.
    private var loss: Loss? {
        guard let start = startDate, let end = endDate else { return nil }
        let range = calendar.startOfDay(for: start)...calendar.startOfDay(for: end)
        let dropped = plan.days.filter {
            !range.contains(calendar.startOfDay(for: $0.date)) && !$0.items.isEmpty
        }
        return dropped.isEmpty ? nil : Loss(days: dropped)
    }

    /// 새 기간 안에 남는 날만. 이것이 서버로 간다.
    private var keptDays: [PlanDay] {
        guard let start = startDate, let end = endDate else { return plan.days }
        let range = calendar.startOfDay(for: start)...calendar.startOfDay(for: end)
        return plan.days.filter { range.contains(calendar.startOfDay(for: $0.date)) }
    }

    private var isUnchanged: Bool {
        guard let start = startDate, let end = endDate else { return true }
        return calendar.isDate(start, inSameDayAs: plan.startDate)
            && calendar.isDate(end, inSameDayAs: plan.endDate)
    }

    private var canSubmit: Bool { startDate != nil && endDate != nil && !isUnchanged }

    private var missingHint: String? {
        if startDate == nil || endDate == nil { "가는 날과 오는 날을 골라 주세요" }
        else if isUnchanged { "날짜가 그대로예요" }
        else { nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            PlanDateRangeCalendar(
                startDate: $startDate,
                endDate: $endDate,
                busyRanges: busyRanges,
                // 이미 떠난 여행도 고칠 수 있어야 한다 — 지금 잡혀 있는 시작일까지는 보여 준다.
                earliestSelectable: plan.startDate
            )

            footer
        }
        .background(Color.white)
        .alert(
            "이 날짜의 일정이 지워져요",
            isPresented: Binding(get: { confirming != nil },
                                 set: { if !$0 { confirming = nil } }),
            presenting: confirming
        ) { _ in
            Button("지우고 저장", role: .destructive) { Task { await save() } }
            Button("취소", role: .cancel) {}
        } message: { loss in
            Text(Self.confirmMessage(loss))
        }
    }

    /// 무엇이 얼마나 사라지는지 **숫자로** 적고, 되돌릴 수 없다는 것을 마지막에 말한다.
    /// 뷰 본문에서 문자열을 이어 붙이면 타입 검사가 느려져 빌드가 멈춘다 — 밖에서 만든다.
    private static func confirmMessage(_ loss: Loss) -> String {
        """
        기간이 줄어들면서 \(loss.summary)가 함께 지워져요. 되돌릴 수 없어요.
        """
    }

    // MARK: 조각

    private var headerBar: some View {
        ZStack {
            Text("날짜 수정")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.notoSans(16, .regular, relativeTo: .body))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            AuthErrorLine(message: saveError)

            // 무엇을 잃는지 **버튼을 누르기 전에도** 보인다. 확인 창은 마지막 방어선이지
            //  처음 알리는 자리가 아니다 — 창이 떠서야 알면 이미 고른 날짜를 다시 재야 한다.
            if let loss {
                Text("이 기간으로 줄이면 \(loss.summary)가 지워져요")
                    .font(.notoSans(14, .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.errorRed)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let missingHint {
                Text(missingHint)
                    .font(.notoSans(14, .regular, relativeTo: .subheadline))
                    .foregroundStyle(Color.textSecondary)
            }

            Button {
                // 잃을 것이 있으면 한 번 묻고, 없으면 바로 저장한다.
                if let loss { confirming = loss } else { Task { await save() } }
            } label: {
                ZStack {
                    Text("저장")
                        .font(.notoSans(16, .bold, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(canSubmit ? Color.textPrimary : Color.iconGray)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.textPrimary) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 47)
                .background(Capsule().fill(canSubmit ? Color.moduwaGreen : Color.photoPlaceholder))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSaving)
            .accessibilityHint(canSubmit ? "" : missingHint ?? "")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func save() async {
        guard let start = startDate, let end = endDate, !isSaving else { return }
        isSaving = true
        saveError = nil
        do {
            try await onSave(start, end, keptDays)
            UIAccessibility.post(notification: .announcement, argument: "날짜를 바꿨어요")
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? "날짜를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요."
            UIAccessibility.post(notification: .announcement, argument: saveError ?? "")
        }
        isSaving = false
    }
}

#Preview("날짜 수정") {
    PlanDateEditView(plan: MockData.upcomingGyeongju) { _, _, _ in }
}
