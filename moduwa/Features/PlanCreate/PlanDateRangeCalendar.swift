import SwiftUI

/// 새 플랜 플로우 3/6의 날짜 범위 달력 — Figma 519:1343
///
/// **구현 방식 판단 — `DatePicker` 두 개가 아니라 직접 만든 달력이다.**
///  ① 시안이 "2일 부터 6일 까지"를 한 화면에서 잇는 띠로 보여 준다. `DatePicker` 두 개로는
///     그 사이가 무엇인지 보이지 않아 "3박 4일"을 눈으로 세게 된다.
///  ② `DatePicker`(.graphical) 두 개는 화면을 두 배로 쓰면서 서로의 범위를 강제하지 못한다
///     (종료일이 시작일보다 앞서는 조합을 막으려면 어차피 직접 검증해야 한다).
///  ③ VoiceOver 조작 가능성은 직접 만들어도 지킬 수 있다 — 날짜 한 칸이 각각 버튼이고
///     "8월 2일 일요일, 출발일" 처럼 읽히며, 다음에 무엇을 고르는 차례인지 힌트로 알려 준다.
///     범위가 정해질 때마다 `.announcement`로 결과를 읽어 주므로 화면을 보지 않아도 확인된다.
///
/// **Dynamic Type 판단** — 7열 격자는 줄바꿈으로 도망갈 곳이 없어 날짜 숫자만 `.xxLarge`에서
///  더 커지지 않게 묶었다. 대신 위쪽 요약("8월 2일 부터 …")과 제목·버튼은 끝까지 커진다 —
///  가장 큰 글자를 쓰는 사용자에게 실제로 정보를 주는 것은 격자가 아니라 그 요약 줄이다.
struct PlanDateRangeCalendar: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    /// 시안은 이번 달과 다음 달을 이어 붙여 스크롤한다. 1년치를 그려 두면
    /// 내년 여행까지 스크롤만으로 닿는다 (달 넘김 버튼이 시안에 없다).
    private static let monthCount = 12

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.top, 26)
                .padding(.bottom, 22)

            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)
                .accessibilityHidden(true)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    ForEach(months, id: \.self) { month in
                        monthSection(month)
                    }
                }
                .padding(.top, 26)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 요약 줄

    /// 시안 532:146 — "8월 2일 부터 —— 8월 6일 까지". 아직 안 고른 쪽은 밑줄 자리로 남긴다.
    private var summary: some View {
        HStack(spacing: 10) {
            endpointText(startDate, suffix: "부터")

            Rectangle()
                .fill(Color.iconGray)
                .frame(width: 37, height: 1)
                .accessibilityHidden(true)

            endpointText(endDate, suffix: "까지")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("고른 날짜")
        .accessibilityValue(summaryValue)
    }

    private func endpointText(_ date: Date?, suffix: String) -> some View {
        HStack(spacing: 3) {
            if let date {
                let parts = calendar.dateComponents([.month, .day], from: date)
                numberText("\(parts.month ?? 0)")
                unitText("월")
                numberText("\(parts.day ?? 0)")
                unitText("일")
            } else {
                // 아직 안 고른 쪽. 빈 자리를 그대로 두면 무엇이 빠졌는지 보이지 않는다.
                numberText("–")
                unitText("월")
                numberText("–")
                unitText("일")
            }
            unitText(suffix).foregroundStyle(Color.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func numberText(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(18, .bold, relativeTo: .headline))
            .foregroundStyle(Color.textPrimary)
    }

    private func unitText(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(15, .medium, relativeTo: .subheadline))
            .foregroundStyle(Color.textPrimary)
    }

    private var summaryValue: String {
        switch (startDate, endDate) {
        case (let start?, let end?):
            "\(PlanDateText.monthDay(start))부터 \(PlanDateText.monthDay(end))까지, \(nightsText(start, end))"
        case (let start?, nil):
            "\(PlanDateText.monthDay(start)) 출발, 도착일을 고르지 않음"
        default:
            "아직 고르지 않음"
        }
    }

    /// "2박 3일" — 스케치가 3/6 화면에 적어 둔 표기다.
    private func nightsText(_ start: Date, _ end: Date) -> String {
        let nights = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return nights == 0 ? "당일" : "\(nights)박 \(nights + 1)일"
    }

    // MARK: - 월

    private var months: [Date] {
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        return (0..<Self.monthCount).compactMap { calendar.date(byAdding: .month, value: $0, to: base) }
    }

    private func monthSection(_ month: Date) -> some View {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return VStack(alignment: .leading, spacing: 16) {
            Text("\(String(parts.year ?? 0))년 \(parts.month ?? 0)월")
                .font(.notoSans(16, .medium, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 36)
                // 표제로 두면 VoiceOver 의 표제 이동으로 달을 건너뛸 수 있다 —
                // 날짜 칸을 하나씩 지나 다음 달까지 가려면 30번 넘게 스와이프해야 한다.
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 3) {
                weekdayRow
                ForEach(Array(weeks(of: month).enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            dayCell(day, in: month)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            // 7열 격자는 줄바꿈할 곳이 없다 (파일 상단 판단 참고)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.notoSans(13, .regular, relativeTo: .footnote))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        // 요일은 아래 각 날짜가 "일요일"까지 읽어 주므로 따로 읽히면 중복이다
        .accessibilityHidden(true)
    }

    private static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    /// 해당 달을 주 단위로 자른다. 앞뒤로 이웃 달 날짜가 섞이며, 그 칸은 회색으로 두고 고를 수 없다
    /// (시안도 7월 26~31일을 회색으로 그려 둔다). 아래·위 달 섹션에서 같은 날짜를 다시 그리므로
    /// 고를 수 있게 두면 같은 날이 두 번 등장해 어느 쪽을 눌렀는지 알 수 없다.
    private func weeks(of month: Date) -> [[Date]] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let leading = calendar.component(.weekday, from: first) - 1
        let total = leading + range.count
        let rows = Int(ceil(Double(total) / 7))

        return (0..<rows).map { row in
            (0..<7).compactMap { column in
                calendar.date(byAdding: .day, value: row * 7 + column - leading, to: first)
            }
        }
    }

    // MARK: - 날짜 한 칸

    @ViewBuilder
    private func dayCell(_ day: Date, in month: Date) -> some View {
        let isThisMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isPast = day < today

        Button {
            // 선택 상태가 바뀌면 띠와 원이 동시에 나타난다 — 애니메이션되면 격자가 출렁인다.
            withoutAnimation { select(day) }
        } label: {
            ZStack {
                rangeBand(for: day)

                Text("\(calendar.component(.day, from: day))")
                    .font(.notoSans(15, isEndpoint(day) ? .bold : .regular, relativeTo: .subheadline))
                    .foregroundStyle(dayColor(isThisMonth: isThisMonth, isPast: isPast, day: day))
                    .frame(width: 32, height: 32)
                    .background {
                        if isEndpoint(day) {
                            Circle().fill(Color.deepGreen)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isThisMonth || isPast)
        .accessibilityLabel(label(for: day))
        .accessibilityValue(value(for: day))
        .accessibilityAddTraits(isEndpoint(day) ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isThisMonth && !isPast ? nextActionHint : "")
        // 이웃 달·지난 날짜는 눌러도 아무 일이 없어 정지점만 늘린다
        .accessibilityHidden(!isThisMonth || isPast)
    }

    private func dayColor(isThisMonth: Bool, isPast: Bool, day: Date) -> Color {
        if isEndpoint(day) { return .white }
        // 고를 수 없는 칸(이웃 달·지난 날짜)만 회색이다. 정보가 아니라 "여기는 없다"는 표시다.
        if !isThisMonth || isPast { return .iconGray }
        return .textPrimary
    }

    /// 시작·종료 두 원을 잇는 띠. 끝점 칸은 원의 **중심부터** 채워야 띠가 원에서 뻗어 나온 것처럼 보인다
    /// (시안 Rectangle 6이 46 → 247, 딱 두 원의 중심 사이다).
    private func rangeBand(for day: Date) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(fillsLeadingHalf(day) ? Color.moduwaGreen.opacity(0.25) : .clear)
            Rectangle().fill(fillsTrailingHalf(day) ? Color.moduwaGreen.opacity(0.25) : .clear)
        }
        .frame(height: 32)
    }

    private func fillsLeadingHalf(_ day: Date) -> Bool {
        guard let start = startDate, let end = endDate, start < end else { return false }
        return day > start && day <= end
    }

    private func fillsTrailingHalf(_ day: Date) -> Bool {
        guard let start = startDate, let end = endDate, start < end else { return false }
        return day >= start && day < end
    }

    private func isEndpoint(_ day: Date) -> Bool {
        [startDate, endDate].contains { $0.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
    }

    private func isInRange(_ day: Date) -> Bool {
        guard let start = startDate, let end = endDate else { return false }
        return day > start && day < end
    }

    // MARK: - 선택

    /// 출발일 → 도착일 순으로 채운다. 이미 둘 다 정해졌거나 출발일보다 앞을 누르면
    /// 그 날짜를 새 출발일로 삼는다 — 끝을 앞으로 당기는 조작을 따로 배우지 않아도 되게.
    private func select(_ day: Date) {
        if let start = startDate, endDate == nil, day >= start {
            endDate = day
        } else {
            startDate = day
            endDate = nil
        }
        // 격자를 보지 않는 사용자에게는 여기가 유일한 확인 지점이다.
        UIAccessibility.post(notification: .announcement, argument: summaryValue)
    }

    private var nextActionHint: String {
        startDate != nil && endDate == nil ? "두 번 탭하면 도착일로 정합니다" : "두 번 탭하면 출발일로 정합니다"
    }

    private func label(for day: Date) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: day)
        let weekday = Self.weekdaySymbols[((parts.weekday ?? 1) - 1) % 7]
        return "\(parts.month ?? 0)월 \(parts.day ?? 0)일 \(weekday)요일"
    }

    private func value(for day: Date) -> String {
        if let start = startDate, calendar.isDate(start, inSameDayAs: day) { return "출발일" }
        if let end = endDate, calendar.isDate(end, inSameDayAs: day) { return "도착일" }
        if isInRange(day) { return "여행 기간" }
        return ""
    }
}

#Preview("날짜 고르기") {
    @Previewable @State var start: Date? = .now
    @Previewable @State var end: Date? = Calendar.current.date(byAdding: .day, value: 4, to: .now)
    PlanDateRangeCalendar(startDate: $start, endDate: $end)
}
