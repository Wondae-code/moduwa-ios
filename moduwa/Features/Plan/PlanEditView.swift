import SwiftUI

/// 일정 편집 — Figma "02-1. 플랜 상세 - 편집 진입시"(519:987)
///
/// 상세와 달리 지도가 없다. 순서를 바꾸는 화면이라 목록 전체가 한눈에 들어와야 하고,
/// 드래그로 행을 옮기는 동안 지도가 계속 다시 그려지면 방해만 된다.
///
/// **순서는 손잡이로 끌어서, 빼기는 카드 안 빨간 `−` 로** 한다 — 왜 이 모양이 됐는지는
/// `RemoveButton` 주석에 적었다.
///
/// 편집 결과는 **완료를 눌러야** 호출부에 넘어간다 — 순서를 이리저리 바꿔 보다가 되돌리고 싶을 때
/// 취소할 길이 있어야 한다.
struct PlanEditView: View {
    /// 완료 시 편집된 날짜 목록을 넘긴다. 저장 책임은 호출부에 있다.
    ///
    /// **저장이 끝날 때까지 기다린다** — 화면을 먼저 닫고 뒤에서 저장하면, 실패했을 때
    /// 사용자는 이미 편집 화면을 떠난 뒤라 방금 맞춰 놓은 순서를 처음부터 다시 만들어야 한다.
    var onDone: ([PlanDay]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var days: [PlanDay]
    /// 지금 보고 있는 날. **하루씩만 보여 준다**(2026-09-20 사용자 지시) — 상세와 같은 모양이다.
    @State private var selectedDayIndex = 0
    @State private var isSaving = false
    /// 저장 실패 사유. 서버가 한국어로 알려 주면 그대로 담는다.
    @State private var saveError: String?

    /// - Parameter days: 편집 대상. **여행 기간 전체**를 넘긴다(`Plan.dayCandidates()`) —
    ///   아직 아무것도 담기지 않은 날에도 항목을 옮길 수 있어야 한다. 빈 채로 남은 날은
    ///   호출부가 저장 때 걸러 낸다.
    init(days: [PlanDay], onDone: @escaping ([PlanDay]) async throws -> Void = { _ in }) {
        self.onDone = onDone
        _days = State(initialValue: days)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let saveError { errorBanner(saveError) }

            if let day = currentDay {
                // 날짜 줄은 목록 **밖**에 세운다 — 함께 스크롤되면 일정이 긴 날에서 화살표가
                //  화면 위로 밀려, 날을 넘기려고 매번 맨 위까지 되돌아와야 한다.
                dayHeader(day)

                if day.items.isEmpty {
                    emptyDay
                    Spacer(minLength: 0)
                } else {
                    list(for: day)
                }
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 보고 있는 날의 목록. 순서는 손잡이로 끌어서 바꾼다.
    private func list(for day: PlanDay) -> some View {
        List {
            ForEach(rows) { row in
                switch row {
                case .item(let item):
                    self.row(for: item, in: day)
                        .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(timelineRowBackground)
                        // **빨간 `−` 기둥만 끄고 드래그 핸들은 남긴다.** 빼기는 카드 안의
                        //  `RemoveButton` 이 맡는다(그 주석에 이유가 있다).
                        .deleteDisabled(true)
                case .distance(_, let text):
                    distanceRow(text)
                        .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(timelineRowBackground)
                        // 거리는 편집 대상이 아니다 — 장소 순서에서 나오는 값이다.
                        .moveDisabled(true)
                        .deleteDisabled(true)
                }
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        // 켜 두는 이유는 **드래그 핸들** 하나다 — 순서를 바꾸는 화면이라 잡는 곳이
        //  늘 보여야 한다. 딸려 오는 빨간 `−` 는 행마다 `deleteDisabled` 로 끈다.
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // MARK: 보고 있는 날

    /// 범위 안으로 밀어 넣은 `selectedDayIndex`. 날짜를 줄인 플랜에서 범위 밖 값이 남을 수 있다.
    private var dayIndex: Int? {
        days.isEmpty ? nil : min(max(selectedDayIndex, 0), days.count - 1)
    }

    private var currentDay: PlanDay? { dayIndex.map { days[$0] } }

    /// 하루 앞뒤로 옮긴다. 양 끝에서는 버튼이 이미 꺼져 있지만 범위를 다시 묶는다.
    private func stepDay(_ delta: Int) {
        guard let index = dayIndex else { return }
        selectedDayIndex = min(max(index + delta, 0), days.count - 1)
    }

    // MARK: 한 날의 목록

    /// 장소·메모와 **거리 줄**을 한 줄로 세운 목록.
    private enum EditRow: Identifiable {
        case item(PlanDayItem)
        /// 앞 장소에서 다음 장소까지의 거리. **장소 카드와 한 행에 두지 않는다** —
        /// 편집 모드의 드래그 핸들은 행 높이의 가운데에 놓이므로, 거리까지 한 행이면 핸들이
        /// 카드 중심보다 아래로 내려간다(거리 줄 높이의 절반만큼). 별도 행으로 빼면 카드 행의
        /// 높이가 카드 그 자체라 핸들이 카드 가운데에 온다.
        case distance(afterItemID: UUID, text: String)

        /// 항목과 거리의 id 가 겹치지 않게 접두사를 붙인다.
        var id: String {
            switch self {
            case .item(let item): "item-\(item.id.uuidString)"
            case .distance(let afterID, _): "gap-\(afterID.uuidString)"
            }
        }
    }

    private var rows: [EditRow] {
        guard let day = currentDay else { return [] }
        var out: [EditRow] = []
        for (position, item) in day.items.enumerated() {
            out.append(.item(item))
            if let text = distanceText(after: position, in: day) {
                out.append(.distance(afterItemID: item.id, text: text))
            }
        }
        return out
    }

    /// `position` 의 장소에서 **다음 장소**까지의 직선 거리. 상세 화면과 같은 규칙이고,
    /// 좌표가 없는 장소가 끼면 구간을 만들지 않는다(`TravelLeg.straightLine`).
    private func distanceText(after position: Int, in day: PlanDay) -> String? {
        guard case .stop(let current) = day.items[position],
              let next = day.stopAfter(position),
              let leg = TravelLeg.straightLine(from: current.place, to: next.place)
        else { return nil }
        return leg.distanceText
    }

    /// **같은 날 안에서** 순서를 바꾼다. 거리 줄이 사이사이 끼어 있어 옮겨진 목록에서
    /// 장소·메모만 다시 걸러 낸다 — 거리는 그 순서에서 새로 계산된다.
    private func move(from source: IndexSet, to destination: Int) {
        guard let index = dayIndex else { return }
        var flat = rows
        flat.move(fromOffsets: source, toOffset: destination)

        let ordered = flat.compactMap { row -> PlanDayItem? in
            if case .item(let item) = row { item } else { nil }
        }
        withAnimation(.snappy(duration: 0.25)) { days[index].items = ordered }
        UIAccessibility.post(notification: .announcement, argument: "순서를 옮겼어요")
    }

    /// 항목을 **고른 날로** 보낸다 — 그 날의 맨 뒤에 붙는다.
    ///
    /// ⚠️ **예전에는 드래그로 날을 넘나들었다**(2026-08-16 사용자 요청). 그러려고 날짜 머리글까지
    /// 한 줄로 세운 평평한 목록을 썼는데, 하루씩만 보이는 지금은 **끌어다 놓을 다른 날이 화면에
    /// 없다.** 능력을 버리지 않으려고 길게 눌러 여는 메뉴로 옮겼다(`dayMoveMenu`).
    ///
    /// 옮긴 뒤에도 **보던 날에 그대로 머문다** — 여러 개를 연달아 보낼 때 날이 따라 넘어가면
    /// 다음 것을 찾으러 매번 되돌아와야 한다. 대신 어디로 갔는지는 소리로 알린다.
    private func moveToDay(_ itemID: UUID, to target: Int) {
        guard let from = dayIndex, from != target, days.indices.contains(target),
              let position = days[from].items.firstIndex(where: { $0.id == itemID })
        else { return }

        withAnimation(.snappy(duration: 0.25)) {
            let item = days[from].items.remove(at: position)
            days[target].items.append(item)
        }
        UIAccessibility.post(notification: .announcement,
                             argument: "DAY \(target + 1) 마지막으로 옮겼어요")
    }

    /// 길게 누르면 열리는 **"다른 날짜로 옮기기"**. 날짜를 직접 고른다(2026-09-20 사용자 지시).
    ///
    /// 한 겹 접어 두는 이유는 **열흘짜리 여행**이다 — 날을 곧바로 펼치면 메뉴가 아홉 줄이 되어
    /// 화면을 덮는다. 접어 두면 무엇을 하는 메뉴인지 한 줄로 읽히고, 날은 그 안에서 고른다.
    ///
    /// 보고 있는 날은 빼 놓는다 — 제자리로 옮기는 것은 아무 일도 아니다.
    @ViewBuilder
    private func dayMoveMenu(_ itemID: UUID) -> some View {
        if days.count > 1 {
            Menu("다른 날짜로 옮기기", systemImage: "calendar") {
                ForEach(otherDays, id: \.self) { index in
                    Button("DAY \(index + 1) · \(PlanDateText.shortWithWeekday(days[index].date))") {
                        moveToDay(itemID, to: index)
                    }
                }
            }
        }
    }

    /// VoiceOver·스위치 제어용. **길게 누르기는 그들이 쓸 수 없는 조작이라** 같은 일을
    /// 평평한 동작 목록으로 한 번 더 낸다 — 접어 둘 곳이 없으므로 날을 바로 늘어놓는다.
    @ViewBuilder
    private func dayMoveActions(_ itemID: UUID) -> some View {
        ForEach(otherDays, id: \.self) { index in
            Button(Self.moveLabel(to: index + 1)) { moveToDay(itemID, to: index) }
        }
    }

    /// 보고 있는 날을 뺀 나머지 날의 번호(0부터).
    private var otherDays: [Int] {
        let current = dayIndex ?? 0
        return days.indices.filter { $0 != current }
    }

    /// "DAY 3으로 옮기기" — 숫자를 **읽은 소리의 받침**으로 보고 조사를 고른다.
    ///
    /// ⚠️ 그냥 "로" 를 붙이면 **"DAY 3로"** 가 나온다 — 삼은 받침이 있어 "3으로" 다.
    /// 같은 부류의 실수가 앞서 한 번 있었다("17곳가 지워져요", 2026-09-20).
    ///
    /// 받침이 없거나 ㄹ 받침이면 "로", 그 밖에는 "으로" 다. 한자어 수사의 끝소리는
    /// **끝자리 숫자**가 정한다 — 3(삼)·6(육)과 0(십·백…)만 받침이 남고,
    /// 1(일)·7(칠)·8(팔)은 ㄹ 이라 "로" 다.
    static func moveLabel(to number: Int) -> String {
        let needsEu = [0, 3, 6].contains(abs(number) % 10)
        return "DAY \(number)" + (needsEu ? "으로" : "로") + " 옮기기"
    }

    /// 장소·거리 행의 배경 — 바탕색 **위에 점선**을 깐다(2026-09-20 피드백).
    ///
    /// ⚠️ **List 전체에 한 번 그릴 수 없다.** 오버레이로 얹으면 스크롤과 따로 놀고, 편집 중
    /// 행이 끌려다니면 선만 제자리에 남는다. `listRowBackground` 로 **행마다 제 몫을 그려**
    /// 이어 붙인다 — 구분선을 숨겨 둔 덕에 조각들이 틈 없이 하나의 선으로 보인다.
    ///
    /// 들여쓰기 48 = 행 들여쓰기 36 + 번호 뱃지(24)의 절반. `listRowBackground` 는 들여쓰기를
    /// 포함한 **행 전체**를 채우므로 둘을 더해야 뱃지 중심에 온다.
    private var timelineRowBackground: some View {
        ZStack(alignment: .topLeading) {
            Color.appBackground
            DashedVerticalLine.track(leadingInset: 48)
        }
    }

    /// 항목 하나를 뺀다 — 카드 안 빨간 `−` 가 부른다(`RemoveButton`).
    ///
    /// **확인 창을 두지 않는다.** 서버에는 지금 보내지 않고, 이 화면의 다른 편집(순서·날짜
    /// 이동)과 같이 "완료" 를 눌러야 한 번에 저장된다 — 잘못 눌렀으면 뒤로 나가면 그만이다.
    /// 되돌릴 수 있는 조작에 확인을 붙이면 매번 두 번 누르게 만들 뿐이다.
    ///
    /// 거리 줄에는 `−` 가 없다 — 편집 대상이 아니라 장소 순서에서 나오는 값이다.
    private func remove(_ itemID: UUID) {
        guard let dayIndex = days.firstIndex(where: { day in
            day.items.contains { $0.id == itemID }
        }) else { return }

        withAnimation(.snappy(duration: 0.25)) {
            days[dayIndex].items.removeAll { $0.id == itemID }
        }
        // 목록에서 줄이 사라지는 것 말고는 결과를 알릴 자리가 없다.
        UIAccessibility.post(notification: .announcement, argument: "일정에서 뺐어요")
    }

    // MARK: 헤더

    private var header: some View {
        HStack(spacing: 0) {
            // 상세는 chevron 이지만 편집은 되돌아가는 뜻이 강해 시안이 화살표(519:1195)를 쓴다.
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .accessibilityLabel("편집 취소")
            // 저장 중 나가면 결과를 알릴 화면이 사라진다
            .disabled(isSaving)

            Text("일정 편집")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .padding(.leading, 14)

            Spacer(minLength: 0)

            Button {
                Task { await save() }
            } label: {
                // 자리를 "완료"와 같게 잡아 둔다 — 스피너로 바뀌며 폭이 줄면 헤더가 흔들린다.
                Text("완료")
                    .font(.notoSans(18, .bold, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundStyle(isSaving ? .clear : Color.deepGreen)
                    .overlay {
                        if isSaving { ProgressView().tint(.deepGreen) }
                    }
            }
            .disabled(isSaving)
            // 스피너는 낭독되지 않는다 — 저장 중임을 라벨로 전한다
            .accessibilityLabel(isSaving ? "저장 중" : "완료")
        }
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: 저장

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            try await onDone(days)
            // 화면이 곧 닫히므로 저장됐다는 사실이 시각적으로는 스크롤 위치 말고 남지 않는다.
            UIAccessibility.post(notification: .announcement, argument: "일정을 저장했어요")
            dismiss()
        } catch {
            // 서버가 사유를 한국어로 준 경우만 그대로 쓴다. URLError 등 시스템 오류의 원문은
            // 사용자가 할 수 있는 일을 알려 주지 못한다.
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "일정을 저장하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isSaving = false
    }

    /// 실패해도 화면은 열려 있다 — 맞춰 둔 순서를 그대로 두고 "완료"를 다시 누르면 된다.
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.deepGreen)
                .accessibilityHidden(true)

            Text(message)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.photoPlaceholder)
        .accessibilityElement(children: .combine)
    }

    // MARK: Day 헤더

    /// 날짜 줄 — 좌우 화살표로 하루씩 오간다. **상세와 같은 모양이다**(2026-09-20 사용자 지시):
    /// 다음 날로 가려면 목록을 끝까지 내려야 했던 것을 화살표 한 번으로 바꿨다.
    private func dayHeader(_ day: PlanDay) -> some View {
        let number = (dayIndex ?? 0) + 1
        return HStack(spacing: 0) {
            dayStepButton("chevron.left", delta: -1, label: "이전 날", isEnabled: number > 1)

            Text("DAY \(number) · \(PlanDateText.shortWithWeekday(day.date))")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(Color.textPrimary)
                // 날짜에 따라 글자 폭이 달라 오른쪽 화살표가 들썩인다. 가장 긴 표기
                // ("DAY 10 · 12/26 목")에 맞춰 자리를 잡아 두면 넘길 때 버튼이 제자리에 있다.
                .frame(minWidth: 132)
                .layoutPriority(1)

            dayStepButton("chevron.right", delta: 1,
                          label: "다음 날", isEnabled: number < days.count)

            Spacer(minLength: 4)

            // 정렬할 것이 없는 날에는 띄우지 않는다 — 눌러도 아무 일이 없는 버튼이 된다.
            if day.stops.count > 2 {
                Button { sortByDistance() } label: {
                    Text("거리순 정렬")
                        .font(.notoSans(16, .medium, relativeTo: .headline))
                        .foregroundStyle(Color.deepGreen)
                        .lineLimit(1)
                }
                .accessibilityHint("첫 장소는 그대로 두고 가까운 곳부터 다시 줄 세웁니다")
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .accessibilityAddTraits(.isHeader)
    }

    /// 하루 넘기기. 양 끝에서는 비활성으로 남겨 둔다 — 사라지면 화살표 자리가 흔들리고,
    /// 여행이 하루뿐인 플랜에서는 두 버튼이 통째로 없어져 줄이 딴 화면처럼 보인다.
    private func dayStepButton(
        _ systemName: String,
        delta: Int,
        label: String,
        isEnabled: Bool
    ) -> some View {
        Button { stepDay(delta) } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.textPrimary : Color.cardStroke)
        .disabled(isEnabled == false)
        .accessibilityLabel(label)
    }

    /// 아직 아무것도 없는 날. 하루씩만 보이므로 이 자리가 비면 **화면이 통째로 빈다** —
    /// 고장이 아니라는 것과, 여기로 옮겨 올 길이 있다는 것을 같이 알린다.
    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("이 날은 아직 비어 있어요")
                .font(.notoSans(15, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)

            Text("다른 날의 일정을 길게 누르면 이 날로 옮길 수 있어요")
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 36)
        .padding(.trailing, 24)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    // MARK: 행

    /// 카드 한 장 **그것만** 한 행이다. 거리는 `distanceRow` 로 따로 나가 있다 —
    /// 그래야 편집 모드의 드래그 핸들이 카드 가운데에 놓인다(`EditRow.distance` 주석).
    @ViewBuilder
    private func row(for item: PlanDayItem, in day: PlanDay) -> some View {
        let index = day.items.firstIndex(where: { $0.id == item.id }) ?? 0
        let itemID = item.id
        return Group {
            switch item {
            case .stop(let stop):
                PlanEditStopRow(number: day.stopNumber(at: index) ?? 0, stop: stop) {
                    remove(itemID)
                }
            case .memo(let memo):
                PlanEditMemoRow(memo: memo) { remove(itemID) }
            }
        }
        // 날을 넘기는 유일한 길이다 — 드래그로 넘나들던 것을 대신한다(`moveToDay`).
        .contextMenu { dayMoveMenu(itemID) }
        .accessibilityActions { dayMoveActions(itemID) }
    }

    /// 장소 사이의 거리 한 줄. 상세 화면과 같은 자리·같은 글씨다.
    private func distanceRow(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(12, .medium, relativeTo: .caption))
            .foregroundStyle(Color.iconGray)
            .padding(.leading, 39)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 첫 장소를 기준으로 가까운 곳부터 다시 줄 세운다(최근접 이웃).
    ///
    /// 최적 경로(TSP)를 풀지 않는다 — 장소가 몇 개뿐이라 차이가 크지 않고, 무엇보다 사용자가
    /// **왜 이 순서가 나왔는지 납득할 수 있어야** 한다. "가까운 데부터"는 설명 가능하지만
    /// 전역 최적해는 직관과 어긋나는 순서를 내놓기도 한다.
    /// 출발지를 고정하는 이유도 같다 — 첫 장소는 보통 숙소나 도착지라 바뀌면 곤란하다.
    private func sortByDistance() {
        guard let dayIndex else { return }
        let items = days[dayIndex].items
        // 메모는 정렬 대상이 아니다. 순서를 잃지 않게 뒤로 모아 둔다.
        let memos = items.filter { if case .memo = $0 { true } else { false } }
        var stops = items.compactMap { item -> PlanStop? in
            if case .stop(let stop) = item { stop } else { nil }
        }
        guard stops.count > 2 else { return }

        var ordered = [stops.removeFirst()]
        while !stops.isEmpty {
            let current = ordered.last!.place
            // 좌표가 없는 장소는 거리를 잴 수 없다 — 맨 뒤로 밀리도록 최댓값을 준다.
            let nearest = stops.indices.min {
                (TravelLeg.straightLine(from: current, to: stops[$0].place)?.meters ?? .max)
                    < (TravelLeg.straightLine(from: current, to: stops[$1].place)?.meters ?? .max)
            }!
            ordered.append(stops.remove(at: nearest))
        }

        let sorted = ordered.map { PlanDayItem.stop($0) } + memos
        withAnimation(.snappy(duration: 0.3)) { days[dayIndex].items = sorted }
        UIAccessibility.post(notification: .announcement, argument: "가까운 순서로 다시 정렬했어요")
    }
}

// MARK: - 행 구성

/// 편집 중 장소 행. 상세(`PlanStopRow`)와 달리 리뷰 버튼이 없다 —
/// 여기서 할 일은 순서 바꾸기이고, 다른 화면으로 나가는 길이 섞이면 편집 흐름이 끊긴다.
private struct PlanEditStopRow: View {
    let number: Int
    let stop: PlanStop
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // 시안은 편집 중 번호를 회색으로 죽인다. 순서가 곧 바뀔 값이라 확정된 정보처럼
            // 보이지 않게 하려는 것으로 읽힌다.
            Text("\(number)")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.iconGray, in: Circle())

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.place.name)
                        .font(.notoSans(16, .medium, relativeTo: .headline))
                        .foregroundStyle(Color.textPrimary)

                    Text(stop.place.subtitle)
                        .font(.notoSans(14, .regular, relativeTo: .subheadline))
                        .foregroundStyle(Color.textSecondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                // 카드 글자는 한 덩어리로 읽힌다. `−` 는 그 옆에 **따로 선** 버튼이다.
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(number)번 \(stop.place.name), \(stop.place.subtitle)")

                RemoveButton(label: "\(stop.place.name) 빼기", action: onRemove)
            }
            .padding(.leading, 16)
            .frame(minHeight: 57)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke, lineWidth: 1)
            }
        }
        .padding(.vertical, 5)
    }
}

/// 일정에서 한 줄을 빼는 버튼 — **빨간 `−` 를 카드 안 오른쪽에** 둔다.
///
/// 편집 모드의 표준 삭제와 **같은 글리프**지만 자리가 다르다. 시스템은 이 원을 행마다
/// **왼쪽 바깥**에 세우는데, 그러면 화면에서 제일 센 색이 세로로 줄지어 서고 정작 이 화면의
/// 일은 순서다 — 시선이 순서가 아니라 삭제로 먼저 갔다(2026-09-07 지적). 카드 안으로
/// 들어오면 같은 뜻을 유지하면서 줄의 무게 중심이 이름으로 돌아온다.
///
/// 그 기둥은 `deleteDisabled(true)` 로 끈다 — **빨간 원만 사라지고 드래그 핸들은 남는다.**
///
/// ⚠️ 스와이프로 옮겨 봤다가 되돌렸다(2026-09-07). **편집 모드에서는 `swipeActions` 가 아예
/// 안 먹어서** 모드를 꺼야 했는데, 그러면 드래그 핸들이 함께 사라진다. 손잡이를 그림으로
/// 되살려 봤지만 이번엔 민 상태의 좌우 간격이 어긋났다 — 시스템이 놓는 버튼 여백(22)과
/// 시안의 손잡이 여백(24)이 서로를 밀어내서, **평소 여백을 11 까지 당겨야만** 맞았다.
/// 늘 보이는 평소 상태를 버리고 잠깐 보이는 민 상태를 얻는 거래라 접었다.
///
/// 색은 시스템 빨강(#FF3B30, 흰 배경에서 3.0:1)이 아니라 앱의 `errorRed`(#BF1414) 다 —
/// 같은 뜻을 더 읽히는 대비로 전한다. 고대비에서는 #A30D0D 로 더 짙어진다.
private struct RemoveButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22))
                // 원은 빨강, 가운데 막대는 흰색 — 시스템 삭제 원과 같은 모양이다.
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.errorRed)
                // 글리프는 22 지만 손가락 자리는 44 다. 카드 높이(57)가 이걸 품는다.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("일정에서 뺍니다. 완료를 눌러야 저장돼요")
    }
}

private struct PlanEditMemoRow: View {
    let memo: PlanMemo
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(memo.text)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)

            RemoveButton(label: "메모 빼기", action: onRemove)
        }
        .padding(.leading, 16)
        .background(Color.photoPlaceholder, in: RoundedRectangle(cornerRadius: 12))
        .padding(.leading, 38)
        .padding(.vertical, 5)
    }
}

#Preview("편집") {
    NavigationStack {
        PlanEditView(days: MockData.upcomingGyeongju.days)
    }
}

#Preview("저장 실패") {
    NavigationStack {
        PlanEditView(days: MockData.upcomingGyeongju.days) { _ in
            throw PlanServiceError.server(message: "일정을 저장하지 못했어요. (서버 점검 중)")
        }
    }
}
