import SwiftUI

/// 새 플랜 플로우 3/6의 날짜 범위 달력 — Figma `958:462`(옛 스케치 `519:1343`·`532:146`)
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
    /// 이미 만든 플랜이 잡아 둔 날짜 — 시안의 회색 알약 + "다른 일정" 범례(`958:462`).
    ///
    /// **고를 수 없다**(2026-09-07 결정). 처음에는 알려 주기만 하는 표시로 뒀는데, 그러면
    /// 같은 날에 두 여행이 잡혀도 앱이 아무 말을 안 한다. 회색으로 칠해 두고 눌리게 두는 것도
    /// 앞뒤가 안 맞는다 — 칠해 놓은 이유가 "여기는 이미 찼다" 이므로 눌리지 않는 게 맞다.
    ///
    /// 그래서 **범위도 이 날짜들을 넘어갈 수 없다.** 못 고르는 날을 사이에 끼운 기간은 만들 수
    /// 없기 때문이다(`clamped(_:from:)`).
    var busyRanges: [ClosedRange<Date>] = []

    /// 시안은 이번 달과 다음 달을 이어 붙여 스크롤한다. 1년치를 그려 두면
    /// 내년 여행까지 스크롤만으로 닿는다 (달 넘김 버튼이 시안에 없다).
    private static let monthCount = 12

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// 드래그가 손끝 아래 날짜를 찾는 데 쓰는 칸 위치. 각 칸이 올려 준다(`DayFrames`).
    @State private var dayFrames: [Date: CGRect] = [:]
    /// 드래그를 시작한 날짜. 드래그 중에만 값이 있다.
    @State private var dragAnchor: Date?
    /// 벽에 부딪힌 횟수. 늘어날 때마다 햅틱이 한 번 울린다(`sensoryFeedback`).
    @State private var wallHits = 0
    /// 지금 벽에 붙어 있는지 — 붙어 있는 동안 계속 울리지 않게 한다.
    @State private var isAgainstWall = false
    private static let gridSpace = "PlanDateGrid"

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.top, 26)
                .padding(.bottom, 22)

            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)
                .accessibilityHidden(true)

            busyLegend

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    ForEach(months, id: \.self) { month in
                        monthSection(month)
                    }
                }
                .padding(.top, 26)
                .padding(.bottom, 12)
                .coordinateSpace(name: Self.gridSpace)
                .onPreferenceChange(DayFrames.self) { dayFrames = $0 }
                // 가로로 끌 때만 깨어나는 팬. 이 뷰가 곧 격자 좌표계의 기준이라
                //  넘어오는 좌표를 그대로 `dayFrames` 와 맞출 수 있다.
                .background {
                    PlanHorizontalPan(onChange: panChanged, onEnd: panEnded)
                }
            }
        }
        // 벽에 막히는 것을 **손으로도** 알린다. 눈으로만 알리면 화면을 보지 않는 사람에게는
        //  아무 일도 일어나지 않은 것과 같다(값 변화가 없으므로 낭독도 안 된다).
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: wallHits)
    }

    // MARK: - 요약 줄

    /// 시안 `958:462` — **두 줄**이다. "가는 날"(Regular 14 `#4D4D4D`) 아래에
    /// "8월 2일 (일)"(Bold 18 `#0B2A1C`)이 오고, 두 열 사이를 가는 선이 잇는다.
    ///
    /// 옛 스케치(`532:146`)는 "8월 2일 부터 —— 8월 6일 까지" 한 줄이었고 앱이 그쪽을 따르고
    /// 있었다. 두 줄로 바뀌면서 **"부터/까지" 라는 말이 라벨로 올라갔다** — 같은 뜻을
    /// 날짜 옆이 아니라 제목 자리에서 말한다.
    private var summary: some View {
        // ⚠️ 두 열을 화면 끝까지 벌리지 않는다. 시안의 `Group 1` 은 폭 **259** 짜리 덩어리가
        //  가운데 놓인 것이고(393 화면에서 좌우 66/68), 선은 그 안에서 **73**을 차지한다.
        //  `maxWidth: .infinity` 로 두면 날짜가 좌우 끝에 붙어 한 쌍으로 안 읽힌다.
        // 선 57 + 양옆 8 = 시안의 73.
        HStack(alignment: .bottom, spacing: 8) {
            endpointColumn("가는 날", date: startDate)

            Rectangle()
                .fill(Color.iconGray)
                .frame(width: 57, height: 1)
                // 선은 날짜 줄 높이에 걸린다(시안에서 두 날짜 사이를 잇는다).
                .padding(.bottom, 11)
                .accessibilityHidden(true)

            endpointColumn("오는 날", date: endDate)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("고른 날짜")
        .accessibilityValue(summaryValue)
    }

    private func endpointColumn(_ title: String, date: Date?) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.textSecondary)

            Text(dateText(date))
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .foregroundStyle(Color.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
    }

    /// "8월 2일 (일)" — 아직 안 고른 쪽은 빈 자리를 그대로 두지 않고 밑줄 자리로 남긴다.
    private func dateText(_ date: Date?) -> String {
        guard let date else { return "– 월 – 일" }
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday = Self.weekdaySymbols[((parts.weekday ?? 1) - 1) % 7]
        return "\(parts.month ?? 0)월 \(parts.day ?? 0)일 (\(weekday))"
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
        let selectable = isThisMonth && !isPast && !isBusy(day)

        Button {
            // 선택 상태가 바뀌면 띠와 원이 동시에 나타난다 — 애니메이션되면 격자가 출렁인다.
            withoutAnimation { select(day) }
        } label: {
            ZStack {
                busyBand(for: day, in: month)
                rangeBand(for: day)

                Text("\(calendar.component(.day, from: day))")
                    .font(.notoSans(15, isEndpoint(day) ? .bold : .regular, relativeTo: .subheadline))
                    .foregroundStyle(dayColor(isThisMonth: isThisMonth, isPast: isPast, day: day))
                    .frame(width: 32, height: 32)
                    .background {
                        if isEndpoint(day) {
                            // 시안 `958:462` 의 시작일·종료일은 **라임**이다(딥그린으로 그리고
                            //  있었다). 위에 얹히는 날짜가 `textPrimary` 라 대비도 라임 쪽이
                            //  낫다 — 흰 글자를 라임에 올리면 1.6:1 로 읽을 수 없다.
                            Circle().fill(Color.moduwaGreen)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            // 드래그가 손끝 아래 날짜를 찾을 수 있게 칸 위치를 모아 올린다 (`dragGesture`).
            .background {
                if selectable {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: DayFrames.self,
                            value: [calendar.startOfDay(for: day):
                                        geometry.frame(in: .named(Self.gridSpace))])
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityLabel(label(for: day))
        .accessibilityValue(value(for: day))
        .accessibilityAddTraits(isEndpoint(day) ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(selectable ? nextActionHint : "")
        // 이웃 달·지난 날짜는 눌러도 아무 일이 없어 정지점만 늘린다.
        //  **다른 일정 날짜는 감추지 않는다** — 왜 못 고르는지 알려 줘야 하고,
        //  값에 "다른 일정 있음" 이 실려 있다(`value(for:)`).
        .accessibilityHidden(!isThisMonth || isPast)
    }

    private func dayColor(isThisMonth: Bool, isPast: Bool, day: Date) -> Color {
        // 라임 원 위의 날짜는 시안이 Bold `#0B2A1C` 다(흰 글자였다 — 라임 위에서 1.6:1).
        if isEndpoint(day) { return .textPrimary }
        // 고를 수 없는 칸(이웃 달·지난 날짜)만 회색이다. 정보가 아니라 "여기는 없다"는 표시다.
        if !isThisMonth || isPast { return .iconGray }
        // 다른 일정 칸은 `iconGray` 로 두지 않는다 — `#E6E6E6` 알약 위에서 1.9:1 이라
        //  읽을 수 없다. 시안도 이 칸의 날짜를 `#4D4D4D` 로 그려 둔다(7.4:1).
        if isBusy(day) { return .textSecondary }
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

    // MARK: - 다른 일정 (시안 958:462)

    /// 이미 만든 플랜이 잡아 둔 날짜를 잇는 **회색 알약**(시안은 `#E6E6E6` 한 덩어리다).
    ///
    /// ⚠️ **한 칸에 한 장만 그린다.** 처음에는 `rangeBand` 처럼 *칸마다 캡슐 + 좌우 반쪽
    /// 사각형*을 겹쳐 놓았는데, 같은 색이어도 **캡슐 테두리의 안티에일리어싱이 사각형 위에
    /// 겹쳐 링으로 남아** 날짜마다 동그라미가 보였다(2026-09-07 실기기 지적). 겹치는 도형이
    /// 없으면 그 링도 없다 — 그래서 모서리만 조건부로 둥근 사각형 하나를 칸 폭에 꽉 채운다.
    /// 옆 칸과 정확히 맞닿아 이어지고, 구간의 양 끝만 둥글다.
    ///
    /// 이웃 달 칸에는 그리지 않는다. 그 칸은 어차피 못 고르는 자리라 회색이 두 뜻이 된다.
    @ViewBuilder
    private func busyBand(for day: Date, in month: Date) -> some View {
        if calendar.isDate(day, equalTo: month, toGranularity: .month), isBusy(day) {
            let opensLeft = !isBusy(dayBefore: day)
            let opensRight = !isBusy(dayAfter: day)
            UnevenRoundedRectangle(
                topLeadingRadius: opensLeft ? 16 : 0,
                bottomLeadingRadius: opensLeft ? 16 : 0,
                bottomTrailingRadius: opensRight ? 16 : 0,
                topTrailingRadius: opensRight ? 16 : 0)
                .fill(Color.cardStroke)
                .frame(height: 32)
        }
    }

    /// **"다른 일정"** 범례(시안 Regular 12 `#B3B3B3`). 회색이 무슨 뜻인지 알린다.
    ///
    /// ⚠️ **줄마다 붙이지 않고 위에 한 번만 둔다**(2026-09-07 요청: "주간 간격이 '다른 일정'
    /// 글자가 있을 때 더 넓어져. 이걸 없애"). 주 아래에 놓으면 그 글자가 레이아웃 공간을
    /// 차지해 **그 주만 높아진다.** 칸 사이 여백은 15pt(칸 44 − 원 32 의 위아래 6 + 줄 간격 3)
    /// 뿐이라 12pt 글자를 끼워 넣을 자리가 없다 — 겹치지 않게 두려면 결국 줄을 늘려야 한다.
    ///
    /// 시안(`958:462`)은 알약 **바로 아래**에 적어 두는데, 그 예시에서는 알약이 달의 마지막
    /// 주에 있어 아래가 비어 있었다. 알약이 가운데 주에 오면 그대로 옮길 수 없다.
    @ViewBuilder
    private var busyLegend: some View {
        if !busyRanges.isEmpty {
            HStack(spacing: 6) {
                Capsule()
                    .fill(Color.cardStroke)
                    .frame(width: 28, height: 14)

                Text("다른 일정")
                    .font(.notoSans(12, .regular, relativeTo: .caption))
                    .foregroundStyle(Color.iconGray)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 40)
            .padding(.top, 14)
            // 날짜 칸이 이미 "다른 일정 있음" 을 값으로 읽어 준다 — 여기서 또 읽으면 겹친다.
            .accessibilityHidden(true)
        }
    }

    private func isBusy(_ day: Date) -> Bool {
        let start = calendar.startOfDay(for: day)
        return busyRanges.contains { $0.contains(start) }
    }

    private func isBusy(dayBefore day: Date) -> Bool {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return false }
        return isBusy(previous)
    }

    private func isBusy(dayAfter day: Date) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        return isBusy(next)
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
        // 다른 일정을 사이에 끼운 기간은 만들 수 없다. 이때 몰래 짧게 줄이면 **누른 날짜와
        //  다른 기간**이 생겨 더 헷갈린다 — 그 날짜를 새 출발일로 삼는다(아래 `else` 와 같다).
        //  드래그는 반대로 벽에서 멈추는 쪽이 자연스러워 `reachable(towards:from:)` 로 자른다.
        if let start = startDate, endDate == nil, day >= start,
           calendar.isDate(reachable(towards: day, from: start), inSameDayAs: day) {
            endDate = day
        } else {
            startDate = day
            endDate = nil
        }
        // 격자를 보지 않는 사용자에게는 여기가 유일한 확인 지점이다.
        UIAccessibility.post(notification: .announcement, argument: summaryValue)
    }

    // MARK: - 드래그로 기간 정하기

    /// 날짜를 **끌어서** 기간을 잡는다(2026-09-07 요청). 누르고 기다릴 필요가 없다.
    ///
    /// 손이 처음 닿은 칸이 기준점이고, 거기서 양쪽으로 늘어난다. 끌다가 **다른 일정이나
    /// 지난 날짜에 닿으면 거기서 멈추고 햅틱이 한 번 울린다.**
    ///
    /// 세로 스크롤과 어떻게 나누는지는 `PlanHorizontalPan` 에 적어 두었다 — 짧게 말하면
    /// SwiftUI `DragGesture` 로는 스크롤이 죽어서 UIKit 인식기로 내려갔다.
    private func panChanged(origin: CGPoint, location: CGPoint) {
        guard let anchor = dragAnchor ?? day(at: origin) else { return }
        if dragAnchor == nil {
            dragAnchor = anchor
            withoutAnimation {
                startDate = anchor
                endDate = nil
            }
        }

        // 다른 일정 위에서는 그대로 둔다 — 벽에 손이 닿아 있는 동안 값이 튀지 않는다.
        guard let target = day(at: location) else { return }
        let reachable = reachable(towards: target, from: anchor)

        // 벽에 **처음 닿는 순간**에만 울린다. 붙어 있는 동안 계속 울리면 소음이 된다.
        let blocked = !calendar.isDate(reachable, inSameDayAs: target)
        if blocked, !isAgainstWall { wallHits += 1 }
        isAgainstWall = blocked

        withoutAnimation {
            startDate = min(anchor, reachable)
            endDate = calendar.isDate(anchor, inSameDayAs: reachable)
                ? nil : max(anchor, reachable)
        }
    }

    private func panEnded() {
        let wasDragging = dragAnchor != nil
        dragAnchor = nil
        isAgainstWall = false
        guard wasDragging else { return }
        // 격자를 보지 않는 사용자에게는 여기가 유일한 확인 지점이다(`select` 와 같다).
        UIAccessibility.post(notification: .announcement, argument: summaryValue)
    }

    /// 격자 좌표계에서 그 지점에 있는 날짜.
    /// 고를 수 없는 칸은 위치를 올리지 않으므로 자연히 걸러진다.
    private func day(at point: CGPoint) -> Date? {
        dayFrames.first { $0.value.contains(point) }?.key
    }

    /// 기준점에서 목표 날짜 **쪽으로 하루씩 걸어가** 닿을 수 있는 마지막 날.
    /// 다른 일정이나 지난 날짜에 막히면 그 앞에서 멈춘다.
    ///
    /// ⚠️ **기준점에서 걸어야 한다.** 범위의 아래쪽 끝에서 걸으면 위로 끌 때와 아래로 끌 때가
    /// 달라진다 — 26일에서 왼쪽으로 끌면 22~25일 벽을 뛰어넘어 21일이 잡혔다(실측 버그).
    /// 방향은 기준점이 정한다.
    private func reachable(towards target: Date, from anchor: Date) -> Date {
        let step = target >= anchor ? 1 : -1
        var last = anchor
        while !calendar.isDate(last, inSameDayAs: target) {
            guard let next = calendar.date(byAdding: .day, value: step, to: last),
                  next >= today, !isBusy(next)
            else { break }
            last = next
        }
        return last
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
        // 회색 알약은 눈으로만 보인다 — 값에 함께 실어야 화면을 안 보고도 알 수 있다.
        let busy = isBusy(day) ? "다른 일정 있음" : ""
        let state: String = {
            if let start = startDate, calendar.isDate(start, inSameDayAs: day) { return "출발일" }
            if let end = endDate, calendar.isDate(end, inSameDayAs: day) { return "도착일" }
            if isInRange(day) { return "여행 기간" }
            return ""
        }()
        return [state, busy].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// 날짜 칸의 위치를 격자 좌표계로 모은다 — 드래그가 손끝 아래 날짜를 찾는 데 쓴다.
/// **고를 수 있는 칸만** 올라오므로 지난 날짜·이웃 달·다른 일정은 드래그에도 안 걸린다.
private struct DayFrames: PreferenceKey {
    static let defaultValue: [Date: CGRect] = [:]

    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("날짜 고르기") {
    @Previewable @State var start: Date? = .now
    @Previewable @State var end: Date? = Calendar.current.date(byAdding: .day, value: 4, to: .now)
    PlanDateRangeCalendar(startDate: $start, endDate: $end)
}
