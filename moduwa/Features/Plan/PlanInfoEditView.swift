import SwiftUI

/// 여행 정보 수정 — **제목과 날짜를 한 화면에서** 고친다(2026-09-20 결정).
///
/// 여행 상세 헤더의 연필과 날짜 줄이 모두 여기로 온다. 처음에는 제목(`PlanTitleEditView`)과
/// 날짜를 따로 뒀는데, 둘 다 "이 여행이 무엇인가" 를 적는 값이라 **나눌 이유가 없었다** —
/// 제목을 고치러 들어와 날짜가 틀린 것을 봐도 나갔다 다시 들어와야 했다.
///
/// **시안 없음.** 메모 추가(`PlanMemoComposeView`)·팀 수정과 같은 틀이다 — 흰 시트,
/// 회색 입력 상자, 라임 캡슐 CTA, 실패 사유를 버튼 위에. 달력은 새 플랜 3/6 의
/// `PlanDateRangeCalendar` 를 그대로 쓴다(같은 질문에 두 가지 달력을 두지 않는다).
///
/// **`alert` 이 아니라 시트인 이유**: 저장이 끝날 때까지 화면이 열려 있어야 실패했을 때
/// 고쳐 쓴 값이 남는다. alert 은 버튼을 누르는 즉시 닫혀 그럴 수가 없다.
///
/// ## 기간을 줄이면 그 날 일정이 사라진다
///
/// 되돌릴 수 없으므로 **저장 전에 무엇이 사라지는지 세어 보여 준다.** 서버가 대신 잘라 주지
/// 않는다 — `PUT /v1/plans/:planId` 는 `days[]` 를 통째로 받으므로 **앱이 계산해서 보낸다.**
/// 그래서 앱이 무엇을 지우는지 정확히 알고 있고, 알면 말할 수 있다.
///
/// 빈 날은 세지 않는다. 날짜만 줄어드는 것은 잃는 것이 없어 물어볼 일이 아니다.
struct PlanInfoEditView: View {
    let plan: Plan
    /// 다른 플랜이 잡아 둔 날짜. **이 플랜 자신의 기간은 빼고** 넘겨야 한다 —
    /// 안 빼면 지금 잡혀 있는 날이 "이미 찼다" 로 막혀 제 날짜를 다시 고를 수 없다.
    var busyRanges: [ClosedRange<Date>] = []
    /// 제목 칸까지 보여 줄지.
    ///
    /// 여는 자리에 따라 다르다 — **연필과 ⋮ 의 "플랜 수정" 은 둘 다**, 상세의 **날짜 줄은
    /// 날짜만** 연다(2026-09-20). 날짜를 고치려고 그 줄을 눌렀는데 제목 칸이 먼저 나오면
    /// 누른 것과 다른 것이 나온 셈이다.
    var editsTitle = true
    /// 새 제목·기간과, 기간 밖으로 밀려난 날을 지운 `days` 를 저장한다.
    /// 제목을 안 고치는 자리에서는 지금 제목이 그대로 돌아온다.
    var onSave: (_ title: String, _ startDate: Date, _ endDate: Date, _ days: [PlanDay]) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var isSaving = false
    @State private var saveError: String?
    /// 잃을 것이 있을 때 띄우는 확인 창. `nil` 이면 닫혀 있다.
    @State private var confirming: Loss?
    @FocusState private var isTitleFocused: Bool

    private let calendar = Calendar.current

    /// 목록 카드와 상세 제목이 두 줄을 넘지 않을 만큼. 서버는 길이를 제한하지 않으므로
    /// (`plans.title` 은 그냥 text) 이 값은 순전히 화면 쪽 판단이다.
    static let titleLimit = 40

    init(plan: Plan,
         busyRanges: [ClosedRange<Date>] = [],
         editsTitle: Bool = true,
         onSave: @escaping (String, Date, Date, [PlanDay]) async throws -> Void) {
        self.plan = plan
        self.busyRanges = busyRanges
        self.editsTitle = editsTitle
        self.onSave = onSave
        _title = State(initialValue: plan.title)
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate)
    }

    // MARK: 무엇이 사라지나

    /// 새 기간 밖으로 밀려나면서 **내용이 있는** 날들.
    struct Loss: Equatable {
        var days: [PlanDay]

        var stopCount: Int { days.reduce(0) { $0 + $1.stops.count } }
        var memoCount: Int { days.reduce(0) { $0 + ($1.items.count - $1.stops.count) } }

        /// 무엇이 사라지는지 **숫자로** 적는다("장소 5곳과 메모 1개"). "일부 일정" 같은
        /// 말로는 무엇을 잃는지 가늠할 수 없어 확인 버튼을 누를 근거가 없다.
        ///
        /// ⚠️ 뒤에 조사를 붙일 문장이므로 **끝 글자의 받침을 봐야 한다**(`withSubject`) —
        /// "곳" 은 받침이 있어 "이", "개" 는 없어 "가" 다. 처음에 "가" 로 고정해 두었다가
        /// "17곳가 사라져요" 가 나왔다(2026-09-20 지적).
        var lostThings: String {
            var parts: [String] = []
            if stopCount > 0 { parts.append("장소 \(stopCount)곳") }
            if memoCount > 0 { parts.append("메모 \(memoCount)개") }
            return parts.isEmpty ? "담아 둔 것" : "담아 둔 " + parts.joined(separator: "과 ")
        }
    }

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

    // MARK: 저장할 수 있나

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var datesChanged: Bool {
        guard let start = startDate, let end = endDate else { return false }
        return !calendar.isDate(start, inSameDayAs: plan.startDate)
            || !calendar.isDate(end, inSameDayAs: plan.endDate)
    }

    /// 제목 칸이 없는 자리에서는 제목이 바뀔 일이 없다.
    private var titleChanged: Bool { editsTitle && trimmedTitle != plan.title }

    /// 제목이 비면 목록 카드에 아무것도 안 남는다 — 빈 제목은 막는다.
    /// 바뀐 것이 없을 때도 막는다 — 서버를 한 번 갔다 올 이유가 없다.
    private var canSubmit: Bool {
        (!editsTitle || !trimmedTitle.isEmpty) && startDate != nil && endDate != nil
            && (titleChanged || datesChanged)
    }

    private var missingHint: String? {
        if editsTitle && trimmedTitle.isEmpty { "제목을 입력해 주세요" }
        else if startDate == nil || endDate == nil { "가는 날과 오는 날을 골라 주세요" }
        else if !titleChanged && !datesChanged { editsTitle ? "바뀐 내용이 없어요" : "날짜가 그대로예요" }
        else { nil }
    }

    // MARK: 문구

    /// 말 뒤에 **주격 조사**를 붙인다 — 받침이 있으면 "이", 없으면 "가".
    ///
    /// 한글 음절은 유니코드에서 `가`(0xAC00)부터 28 개씩 묶여 있고, 그 안에서의 자리가
    /// 곧 받침이다(0 이면 받침 없음). 한글이 아닌 글자로 끝나면 "가" 로 둔다 — 이 화면에
    /// 들어올 말은 "곳"·"개"·"것" 뿐이라 그 경우가 없다.
    private static func withSubject(_ word: String) -> String {
        guard let last = word.unicodeScalars.last,
              (0xAC00...0xD7A3).contains(last.value) else { return word + "가" }
        return word + ((last.value - 0xAC00) % 28 == 0 ? "가" : "이")
    }

    /// 버튼 위에 미리 띄우는 한 줄.
    ///
    /// **며칠이 빠지는지는 말하지 않는다** — 달력에 이미 보이는 사실이고, 걱정되는 것은
    /// 날짜가 아니라 **담아 둔 것이 사라진다**는 쪽이다. 동사도 "담다" 로 맞췄다 —
    /// 장소를 넣을 때 앱이 쓰는 말이라, 사용자가 한 행동을 그대로 되짚어 준다.
    static func lossLine(_ loss: Loss) -> String {
        "\(withSubject(loss.lostThings)) 사라져요"
    }

    /// 확인 창 본문. 뷰 본문에서 문자열을 이어 붙이면 타입 검사가 느려져 빌드가 멈춘다 —
    /// 밖에서 만든다.
    private static func confirmMessage(_ loss: Loss) -> String {
        "\(withSubject(loss.lostThings)) 사라져요. 되돌릴 수 없어요."
    }

    // MARK: 본문

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if editsTitle {
                titleField
                Divider().overlay(Color.cardStroke)
            }

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

    private var headerBar: some View {
        ZStack {
            Text(editsTitle ? "여행 정보 수정" : "날짜 수정")
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
        .padding(.bottom, 12)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("여행 제목을 입력해 주세요", text: $title, axis: .vertical)
                .font(.notoSans(15, relativeTo: .subheadline))
                .foregroundStyle(Color.textPrimary)
                .tint(.deepGreen)
                .lineLimit(1...2)
                .focused($isTitleFocused)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
                .onChange(of: title) {
                    // 줄바꿈은 제목에 들어갈 자리가 없다 — 붙여넣기로 들어오는 것까지 막는다.
                    let flattened = title.replacingOccurrences(of: "\n", with: " ")
                    let capped = String(flattened.prefix(Self.titleLimit))
                    if capped != title { title = capped }
                }
                .accessibilityLabel("여행 제목")

            Text("\(title.count) / \(Self.titleLimit)")
                .font(.notoSans(13, .medium, relativeTo: .caption))
                .foregroundStyle(title.count >= Self.titleLimit ? Color.deepGreen : Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(title.count)자 입력, 최대 \(Self.titleLimit)자")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            AuthErrorLine(message: saveError)

            // 무엇을 잃는지 **버튼을 누르기 전에도** 보인다. 확인 창은 마지막 방어선이지
            //  처음 알리는 자리가 아니다 — 창이 떠서야 알면 이미 고른 날짜를 다시 재야 한다.
            if let loss {
                Text(Self.lossLine(loss))
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
        guard let start = startDate, let end = endDate, !isSaving, canSubmit else { return }
        isSaving = true
        saveError = nil
        do {
            try await onSave(trimmedTitle, start, end, keptDays)
            UIAccessibility.post(notification: .announcement, argument: "저장했어요")
            dismiss()
        } catch {
            saveError = (error as? LocalizedError)?.errorDescription
                ?? "저장하지 못했어요. 잠시 후 다시 시도해 주세요."
            UIAccessibility.post(notification: .announcement, argument: saveError ?? "")
        }
        isSaving = false
    }
}

#Preview("여행 정보 수정") {
    PlanInfoEditView(plan: MockData.upcomingGyeongju) { _, _, _, _ in }
}
