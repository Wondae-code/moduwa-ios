import SwiftUI

/// 일정 편집 — Figma "02-1. 플랜 상세 - 편집 진입시"(519:987)
///
/// 상세와 달리 지도가 없다. 순서를 바꾸는 화면이라 목록 전체가 한눈에 들어와야 하고,
/// 드래그로 행을 옮기는 동안 지도가 계속 다시 그려지면 방해만 된다.
///
/// 편집 결과는 **완료를 눌러야** 호출부에 넘어간다 — 순서를 이리저리 바꿔 보다가 되돌리고 싶을 때
/// 취소할 길이 있어야 한다.
struct PlanEditView: View {
    let plan: Plan
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

    init(plan: Plan, onDone: @escaping ([PlanDay]) async throws -> Void = { _ in }) {
        self.plan = plan
        self.onDone = onDone
        _days = State(initialValue: plan.days)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let saveError { errorBanner(saveError) }

            List {
                ForEach($days) { $day in
                    Section {
                        // onMove 는 Section 안의 ForEach 에 붙어야 그 날 안에서만 순서가 바뀐다.
                        //  Day 를 넘나드는 이동은 날짜가 바뀌는 편집이라 별개 동작으로 다뤄야 한다.
                        ForEach(day.items) { item in
                            row(for: item, in: day)
                                .listRowInsets(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 24))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.appBackground)
                        }
                        .onMove { source, destination in
                            withAnimation(.snappy(duration: 0.25)) {
                                day.items.move(fromOffsets: source, toOffset: destination)
                            }
                        }
                    } header: {
                        dayHeader(for: $day)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
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

    private func dayHeader(for day: Binding<PlanDay>) -> some View {
        let number = (days.firstIndex(where: { $0.id == day.wrappedValue.id }) ?? 0) + 1
        return HStack(spacing: 0) {
            Text("DAY \(number) · \(PlanDateText.shortWithWeekday(day.wrappedValue.date))")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 8)

            Button {
                sortByDistance(day)
            } label: {
                Text("거리순 정렬")
                    .font(.notoSans(16, .medium, relativeTo: .headline))
                    .foregroundStyle(Color.deepGreen)
            }
            .accessibilityHint("첫 장소는 그대로 두고 가까운 곳부터 다시 줄 세웁니다")
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .textCase(nil)
    }

    // MARK: 행

    @ViewBuilder
    private func row(for item: PlanDayItem, in day: PlanDay) -> some View {
        let index = day.items.firstIndex(where: { $0.id == item.id }) ?? 0
        VStack(alignment: .leading, spacing: 0) {
            switch item {
            case .stop(let stop):
                PlanEditStopRow(number: day.stopNumber(at: index) ?? 0, stop: stop)
            case .memo(let memo):
                PlanEditMemoRow(memo: memo)
            }

            // 상세와 같은 규칙 — 앞 장소에서 여기까지의 직선 거리.
            if case .stop = item,
               let next = day.stopAfter(index),
               case .stop(let current) = item,
               let leg = TravelLeg.straightLine(from: current.place, to: next.place) {
                Text(leg.distanceText)
                    .font(.notoSans(12, .medium, relativeTo: .caption))
                    .foregroundStyle(Color.iconGray)
                    .padding(.leading, 39)
                    .padding(.vertical, 8)
            }
        }
    }

    /// 첫 장소를 기준으로 가까운 곳부터 다시 줄 세운다(최근접 이웃).
    ///
    /// 최적 경로(TSP)를 풀지 않는다 — 장소가 몇 개뿐이라 차이가 크지 않고, 무엇보다 사용자가
    /// **왜 이 순서가 나왔는지 납득할 수 있어야** 한다. "가까운 데부터"는 설명 가능하지만
    /// 전역 최적해는 직관과 어긋나는 순서를 내놓기도 한다.
    /// 출발지를 고정하는 이유도 같다 — 첫 장소는 보통 숙소나 도착지라 바뀌면 곤란하다.
    private func sortByDistance(_ day: Binding<PlanDay>) {
        let items = day.wrappedValue.items
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
        withAnimation(.snappy(duration: 0.3)) { day.wrappedValue.items = sorted }
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
        PlanEditView(plan: MockData.upcomingGyeongju)
    }
}

#Preview("저장 실패") {
    NavigationStack {
        PlanEditView(plan: MockData.upcomingGyeongju) { _ in
            throw PlanServiceError.server(message: "일정을 저장하지 못했어요. (서버 점검 중)")
        }
    }
}
