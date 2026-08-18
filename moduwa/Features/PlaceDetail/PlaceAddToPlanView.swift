import SwiftUI

/// 장소 상세의 "일정추가" — 이 장소를 어느 플랜의 어느 날에 담을지 고른다.
///
/// **플랜 상세의 "장소 추가"와 방향이 반대다.** 그쪽은 플랜과 날이 이미 정해진 채로
/// 장소를 찾는 자리라 날짜를 묻지 않는다(2026-08-16 지시). 여기는 장소가 정해진 채로
/// 시작하니 담을 곳을 물어야 한다 — 플랜을 고르고, 그 플랜의 날을 고른다.
///
/// 플랜을 누르면 그 자리에서 날 목록이 **펼쳐진다.** 별도 화면으로 밀지 않는 이유는
/// 두 단계가 한 가지 결정("어디에 담을까")이고, 화면을 넘기면 방금 고른 플랜이
/// 시야에서 사라져 무엇의 날을 고르는지 흐려지기 때문이다.
struct PlaceAddToPlanView: View {
    /// 담을 장소. 상세에서 넘어온 그대로다.
    let place: Place

    @Environment(\.dismiss) private var dismiss
    @Environment(\.planService) private var planService

    @State private var state: LoadState = .loading
    /// 펼쳐 둔 플랜. 한 번에 하나만 펼친다 — 여러 개가 열려 있으면 어느 날을 누르는지 헷갈린다.
    @State private var expandedPlanID: Plan.ID?
    /// 담는 중인 날. 누른 줄에만 진행 표시를 띄운다.
    @State private var savingDayID: PlanDay.ID?
    @State private var saveError: String?

    enum LoadState {
        case loading
        case loaded([Plan])
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            content
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    // MARK: - 헤더

    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .foregroundStyle(.textPrimary)
            .accessibilityLabel("닫기")

            Text("일정에 담기")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            loadingState
        case .failed:
            failedState
        case .loaded(let plans):
            if plans.isEmpty { emptyState } else { planList(plans) }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.deepGreen)
            Text("내 일정을 불러오는 중이에요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("내 일정을 불러오는 중이에요")
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            PlaceSearchMessage(title: "일정을 불러오지 못했어요",
                               subtitle: "네트워크를 확인한 뒤 다시 시도해 주세요")
            Button("다시 시도") { Task { await load() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 담을 곳이 없으면 여기서 만들 길을 주지 않는다 — 플랜을 만드는 것은 여행 기간·지역·동행을
    /// 정하는 여러 단계라 이 시트에 넣을 수 없다. 어디로 가면 되는지만 알린다.
    private var emptyState: some View {
        PlaceSearchMessage(title: "담을 일정이 없어요",
                           subtitle: "플랜 탭에서 여행 계획을 먼저 만들어 주세요")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func planList(_ plans: [Plan]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("‘\(place.name)’을(를) 담을 일정을 골라 주세요")
                    .font(.notoSans(14))
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                if let saveError {
                    Text(saveError)
                        .font(.notoSans(13))
                        .foregroundStyle(.deepGreen)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(plans) { plan in
                    planRow(plan)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - 플랜 한 줄 (누르면 날이 펼쳐진다)

    @ViewBuilder
    private func planRow(_ plan: Plan) -> some View {
        let isExpanded = expandedPlanID == plan.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                // 펼치고 접는 것은 애니메이션 없이 — 열린 목록이 커서 늘어나는 모습이
                // 손가락보다 늦게 따라오면 어긋나 보인다(메모 추가에서 겪은 것과 같다).
                withoutAnimation {
                    expandedPlanID = isExpanded ? nil : plan.id
                    saveError = nil
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(plan.title)
                                .font(.notoSans(16, .bold, relativeTo: .headline))
                                .tracking(-0.4)
                                .foregroundStyle(.textPrimary)
                                .lineLimit(1)

                            // 초안(플랜)과 확정(일정)을 구분해 보인다 — 둘 다 담을 수 있지만
                            // 확정된 여행에 담는 것은 무게가 다르다.
                            Text(plan.isDraft ? "초안" : "확정")
                                .font(.notoSans(11, .bold))
                                .foregroundStyle(plan.isDraft ? Color.textSecondary : .white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(plan.isDraft ? Color.photoPlaceholder : Color.deepGreen)
                                )
                        }

                        Text(plan.dottedDateRangeText)
                            .font(.notoSans(13))
                            .foregroundStyle(.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.iconGray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(plan.title), \(plan.isDraft ? "초안" : "확정"), \(plan.dottedDateRangeText)")
            .accessibilityHint(isExpanded ? "두 번 탭하면 날짜 목록을 접습니다" : "두 번 탭하면 날짜를 고릅니다")
            .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)

            if isExpanded {
                dayList(plan)
            }
        }
        .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))
    }

    /// 여행 기간의 **모든 날**을 후보로 준다(`dayCandidates`) — 아직 아무것도 안 담긴 날도
    /// 담을 자리가 되어야 한다. 서버에 이미 있는 날은 담긴 수를 함께 보인다.
    @ViewBuilder
    private func dayList(_ plan: Plan) -> some View {
        let candidates = plan.dayCandidates()

        VStack(spacing: 0) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
                .padding(.horizontal, 16)

            // 여행이 길면 안에서만 스크롤한다 — 30일 여행이 시트 전체를 밀어내지 않게.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, day in
                        dayRow(plan: plan, day: day, number: index + 1)
                        if index < candidates.count - 1 {
                            Rectangle().fill(Color.cardStroke.opacity(0.6)).frame(height: 1)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            // 다섯 줄쯤 보이고 그 뒤로는 안에서 스크롤한다.
            .frame(maxHeight: candidates.count > 5 ? 250 : .infinity)
            .fixedSize(horizontal: false, vertical: candidates.count <= 5)
        }
    }

    private func dayRow(plan: Plan, day: PlanDay, number: Int) -> some View {
        // 목록에서 온 플랜은 `days` 가 비어 있어 담긴 수를 `daySummaries` 에서 읽는다.
        let stopCount = plan.daySummaries.first { day.isSameDay(as: $0.date) }?.placeNames.count
        let isSaving = savingDayID == day.id

        return Button {
            Task { await add(to: day, in: plan) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.title(number: number))
                        .font(.notoSans(14, .medium))
                        .foregroundStyle(.textPrimary)

                    Text(stopCount.map { $0 > 0 ? "\($0)곳 담김" : "아직 비어 있어요" }
                        ?? "아직 비어 있어요")
                        .font(.notoSans(12))
                        .foregroundStyle(.textSecondary)
                }

                Spacer(minLength: 0)

                if isSaving {
                    ProgressView().tint(.deepGreen)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.deepGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 담는 동안 다른 날을 누르면 두 번 저장돼 서버의 마지막 PUT 만 남는다.
        .disabled(savingDayID != nil)
        .accessibilityElement(children: .combine)
        .accessibilityHint("두 번 탭하면 이 날에 담습니다")
    }

    // MARK: - 동작

    private func load() async {
        state = .loading
        do {
            // 초안(플랜)과 확정(일정)을 **모두** 준다 — 확정된 여행에도 장소를 더할 수 있다.
            state = .loaded(try await planService.fetchPlans())
        } catch {
            state = .failed
        }
    }

    /// 그 날 맨 뒤에 붙이고 플랜을 통째로 저장한다(플랜 상세의 담기와 같은 규칙).
    private func add(to day: PlanDay, in plan: Plan) async {
        savingDayID = day.id
        saveError = nil
        defer { savingDayID = nil }

        do {
            // ⚠️ **목록에서 온 플랜으로 바로 저장하면 안 된다.** `savePlan` 은 PUT 으로 본문을
            //  통째로 갈아 끼우는데 목록의 `days` 는 빈 배열이라 서버의 일정이 지워진다.
            var target = try await planService.fetchPlan(id: plan.id)

            // ⚠️ **id 가 아니라 날짜로 찾는다.** 고른 날은 목록 플랜의 `dayCandidates` 가 만든
            //  후보라 id 가 새로 지어진 값일 수 있다. 상세의 진짜 날은 다른 id 를 갖고 있어
            //  id 로 맞추면 같은 날이 하나 더 생긴다.
            let stop = PlanDayItem.stop(PlanStop(place: PlanPlace(searchResult: place)))
            if let index = target.days.firstIndex(where: { day.isSameDay(as: $0.date) }) {
                target.days[index].items.append(stop)
            } else {
                // 아직 서버에 없는 날. 실제로 담길 때 비로소 생긴다 —
                // 미리 빈 날을 만들어 두면 아무것도 안 담은 날이 타임라인에 줄줄이 남는다.
                target.days.append(PlanDay(date: day.date, items: [stop]))
                target.days.sort { $0.date < $1.date }
            }

            _ = try await planService.savePlan(target, authorNm: nil)
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(plan.title)에 담았어요")
            dismiss()
        } catch {
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "일정에 담지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview("일정에 담기") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlaceAddToPlanView(place: MockData.recommendedPlaces[0])
                .environment(\.planService, MockPlanService())
        }
}
