import SwiftUI

/// 일정 편집 — Figma "02-1. 플랜 상세 - 편집 진입시"(519:987)
///
/// 상세와 달리 지도가 없다. 순서를 바꾸는 화면이라 목록 전체가 한눈에 들어와야 하고,
/// 드래그로 행을 옮기는 동안 지도가 계속 다시 그려지면 방해만 된다.
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

            // Day 를 **넘나들며** 옮길 수 있어야 한다(2026-08-16 사용자 요청).
            //  그래서 Section + Section별 ForEach 구조를 버렸다 — SwiftUI 의 `onMove` 는
            //  자기 ForEach 안에서만 자리를 바꿔서, 섹션이 나뉜 순간 Day 간 이동이 원천적으로 막힌다.
            //  대신 **날짜 머리글까지 한 줄로 세운 평평한 목록**을 만들고 이동은 하나의 onMove 가 받는다.
            //  옮긴 뒤에는 "어느 머리글 아래에 있느냐"로 각 항목의 날을 다시 계산한다(`rebuild`).
            List {
                ForEach(rows) { row in
                    switch row {
                    case .header(let index):
                        dayHeader(index: index)
                            .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.appBackground)
                            // 머리글이 끌려다니면 날짜 순서가 뒤바뀐다. 날짜는 편집 대상이 아니다.
                            .moveDisabled(true)
                            // 날짜 자체는 지울 수 없다 — 여행 기간에서 나오는 값이다.
                            .deleteDisabled(true)
                    case .item(let dayIndex, let item):
                        self.row(for: item, in: days[dayIndex])
                            .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.appBackground)
                    case .distance(_, let text):
                        distanceRow(text)
                            .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.appBackground)
                            // 거리는 편집 대상이 아니다 — 장소 순서에서 나오는 값이다.
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: 평평한 목록

    /// 날짜 머리글과 항목을 한 줄로 세운 목록. Day 간 이동을 하나의 `onMove` 로 받기 위한 형태다.
    private enum EditRow: Identifiable {
        case header(dayIndex: Int)
        case item(dayIndex: Int, item: PlanDayItem)
        /// 앞 장소에서 다음 장소까지의 거리. **장소 카드와 한 행에 두지 않는다** —
        /// 편집 모드의 드래그 핸들은 행 높이의 가운데에 놓이므로, 거리까지 한 행이면 핸들이
        /// 카드 중심보다 아래로 내려간다(거리 줄 높이의 절반만큼). 별도 행으로 빼면 카드 행의
        /// 높이가 카드 그 자체라 핸들이 카드 가운데에 온다.
        case distance(afterItemID: UUID, text: String)

        /// 머리글과 항목의 id 가 겹치지 않게 접두사를 붙인다.
        var id: String {
            switch self {
            case .header(let index): "day-\(index)"
            case .item(_, let item): "item-\(item.id.uuidString)"
            case .distance(let afterID, _): "gap-\(afterID.uuidString)"
            }
        }
    }

    private var rows: [EditRow] {
        days.enumerated().flatMap { index, day -> [EditRow] in
            var out: [EditRow] = [.header(dayIndex: index)]
            for (position, item) in day.items.enumerated() {
                out.append(.item(dayIndex: index, item: item))
                if let text = distanceText(after: position, in: day) {
                    out.append(.distance(afterItemID: item.id, text: text))
                }
            }
            return out
        }
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

    private func move(from source: IndexSet, to destination: Int) {
        var flat = rows
        flat.move(fromOffsets: source, toOffset: destination)
        withAnimation(.snappy(duration: 0.25)) { rebuild(from: flat) }

        // 다른 날로 건너간 경우 화면만 보고는 알아채기 어렵다 — 스크린리더에도 알린다.
        UIAccessibility.post(notification: .announcement, argument: "순서를 옮겼어요")
    }

    /// 항목을 지운다. 편집 모드의 표준 삭제(빨간 −)를 그대로 쓴다 — iOS 가 한 번 더
    /// "삭제"를 눌러야 지워지게 해 주므로 별도 확인 창을 두지 않는다.
    ///
    /// ⚠️ **시안(519:987)에는 삭제 어피던스가 없다**(드래그 핸들만). 그래도 두는 이유: 담은
    /// 장소·메모를 뺄 길이 아예 없어 잘못 담으면 되돌릴 수 없었다. 날짜 머리글은
    /// `deleteDisabled` 로 막았다.
    ///
    /// 서버에는 지금 보내지 않는다 — 이 화면의 다른 편집(순서·날짜 이동)과 같이 "완료"를
    /// 누를 때 한 번에 저장된다. 지우고 나가면 지워지지 않는다.
    private func delete(at offsets: IndexSet) {
        let targets = offsets.compactMap { index -> (dayIndex: Int, itemID: UUID)? in
            guard case .item(let dayIndex, let item) = rows[index] else { return nil }
            return (dayIndex, item.id)
        }
        guard !targets.isEmpty else { return }

        withAnimation(.snappy(duration: 0.25)) {
            for target in targets {
                days[target.dayIndex].items.removeAll { $0.id == target.itemID }
            }
        }
        // 목록에서 줄이 사라지는 것 말고는 결과를 알릴 자리가 없다.
        UIAccessibility.post(notification: .announcement,
                             argument: targets.count == 1 ? "항목을 지웠어요"
                                                          : "\(targets.count)개를 지웠어요")
    }

    /// 옮겨진 평평한 목록을 다시 날짜별로 나눈다 — **머리글이 곧 경계**다.
    private func rebuild(from flat: [EditRow]) {
        var buckets = [[PlanDayItem]](repeating: [], count: days.count)
        var current = 0
        var passedFirstHeader = false

        for row in flat {
            switch row {
            case .header(let index):
                current = index
                passedFirstHeader = true
            case .item(_, let item):
                // 첫 머리글보다 위로 끌어올린 항목은 갈 곳이 없다 — 첫 날에 담는다.
                buckets[passedFirstHeader ? current : 0].append(item)
            case .distance:
                // 거리는 장소 순서에서 파생되는 값이라 다시 계산된다 — 옮겨진 목록에서는 무시한다.
                break
            }
        }

        for index in days.indices { days[index].items = buckets[index] }
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

    private func dayHeader(index: Int) -> some View {
        let day = days[index]
        return HStack(spacing: 0) {
            Text("DAY \(index + 1) · \(PlanDateText.shortWithWeekday(day.date))")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 8)

            // 정렬할 것이 없는 날에는 띄우지 않는다 — 눌러도 아무 일이 없는 버튼이 된다.
            if day.stops.count > 2 {
                Button {
                    sortByDistance(index)
                } label: {
                    Text("거리순 정렬")
                        .font(.notoSans(16, .medium, relativeTo: .headline))
                        .foregroundStyle(Color.deepGreen)
                }
                .accessibilityHint("첫 장소는 그대로 두고 가까운 곳부터 다시 줄 세웁니다")
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: 행

    /// 카드 한 장 **그것만** 한 행이다. 거리는 `distanceRow` 로 따로 나가 있다 —
    /// 그래야 편집 모드의 드래그 핸들이 카드 가운데에 놓인다(`EditRow.distance` 주석).
    @ViewBuilder
    private func row(for item: PlanDayItem, in day: PlanDay) -> some View {
        let index = day.items.firstIndex(where: { $0.id == item.id }) ?? 0
        switch item {
        case .stop(let stop):
            PlanEditStopRow(number: day.stopNumber(at: index) ?? 0, stop: stop)
        case .memo(let memo):
            PlanEditMemoRow(memo: memo)
        }
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
    private func sortByDistance(_ dayIndex: Int) {
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

    var body: some View {
        HStack(spacing: 14) {
            // 시안은 편집 중 번호를 회색으로 죽인다. 순서가 곧 바뀔 값이라 확정된 정보처럼
            // 보이지 않게 하려는 것으로 읽힌다.
            Text("\(number)")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.iconGray, in: Circle())

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
            .padding(.leading, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 57)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke, lineWidth: 1)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number)번 \(stop.place.name), \(stop.place.subtitle)")
    }
}

private struct PlanEditMemoRow: View {
    let memo: PlanMemo

    var body: some View {
        Text(memo.text)
            .font(.notoSans(14, .regular, relativeTo: .subheadline))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
