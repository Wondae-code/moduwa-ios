import SwiftUI

/// 일정 탭 — Figma "03. 일정"(532:241)
///
/// 플랜 탭과 **같은 `Plan` 데이터**를 본다. 다른 것은 보여 주는 방식이다 —
/// 플랜 탭이 만들고 관리하는 곳이라면 여기는 짜 놓은 일정을 훑어보는 곳이라,
/// 지난/예정을 세그먼트로 갈라 놓고 카드마다 그날 동선까지 펼쳐 준다.
///
/// 그래서 조회·삭제는 `PlanService` 를 그대로 쓰고 카드만 다르다(`ScheduleCard`).
struct ScheduleView: View {
    @Environment(\.planService) private var planService

    @State private var state: PlanListState = .loading
    @State private var selectedTab: ScheduleTab = .upcoming
    @State private var path: [Plan] = []
    /// 삭제 확인 대상. nil 이면 확인 창이 닫혀 있다.
    @State private var deleteTarget: Plan?
    @State private var deletingID: Plan.ID?
    @State private var deleteError: String?
    /// "플랜으로 되돌리기" 진행 중인 플랜.
    @State private var revertingID: Plan.ID?
    @State private var revertError: String?

    /// 시안은 카드를 393폭 안에서 321로 두어 좌우 36을 남긴다(플랜 탭과 같다).
    private static let sideMargin: CGFloat = 36

    /// 시안 세그먼트 순서 그대로 — 지난 / 예정 / 컬렉션.
    enum ScheduleTab: String, CaseIterable, Hashable {
        case past = "지난 일정"
        case upcoming = "예정된 일정"
        case collection = "여행 컬렉션"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header
                UnderlineTabBar(tabs: ScheduleTab.allCases, selection: $selectedTab)
                content
            }
            .background(Color.appBackground)
            .navigationDestination(for: Plan.self) {
                PlanDetailView(plan: $0, onPlanSaved: planSaved)
            }
        }
        .task { await load() }
        // 되돌릴 수 없는 삭제라 한 번 묻는다. `confirmationDialog`이 아니라 `alert`인 이유는
        // 플랜 목록과 같다 — iOS 26 의 확인 시트는 누른 자리에 붙는 말풍선이라 카드가 화면
        // 위쪽이면 "취소"가 잘린다. 경고창은 늘 화면 가운데라 두 선택지가 언제나 함께 보인다.
        .alert(
            "이 일정을 삭제할까요?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            presenting: deleteTarget
        ) { plan in
            Button("삭제", role: .destructive) { Task { await delete(plan) } }
            Button("취소", role: .cancel) {}
        } message: { plan in
            Text("‘\(plan.title)’의 일정과 메모가 함께 지워지고 되돌릴 수 없어요.")
        }
        .alert("플랜으로 되돌리지 못했어요", isPresented: Binding(
            get: { revertError != nil }, set: { if !$0 { revertError = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(revertError ?? "")
        }
        .alert("일정을 삭제하지 못했어요", isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Text("내 일정")
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .tracking(-0.4)

            Spacer(minLength: 0)

            // 메뉴는 아직 목적지가 없다 — 플랜 탭과 같은 방식으로 알린다.
            PlanPlaceholderButton(notice: "메뉴는 아직 준비 중이에요") {
                Image("hamburger")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 26, height: 26)
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .collection:
            // 시안에 선택 상태 프레임이 없어 무엇을 담는지 정해지지 않았다.
            // 저장 탭의 "저장 모아보기"와 이름이 겹쳐 기획 확인이 먼저다.
            ComingSoonView(
                title: "여행 컬렉션",
                systemImage: "square.stack",
                message: "여행 컬렉션은 준비 중이에요"
            )
        case .past, .upcoming:
            planList
        }
    }

    @ViewBuilder
    private var planList: some View {
        ScrollView {
            Group {
                switch state {
                case .loading:
                    message("일정을 불러오는 중이에요", isLoading: true)
                case .failed:
                    failedRow
                case .loaded:
                    let plans = visiblePlans
                    if plans.isEmpty {
                        message(emptyText, isLoading: false)
                    } else {
                        LazyVStack(spacing: 40) {
                            ForEach(plans) { plan in
                                cardRow(plan)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Self.sideMargin)
            .padding(.top, 40)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }

    /// ⋮ 는 링크의 **형제**다. 카드 안에 넣으면 ⋮ 를 누른 손가락이 상세로도 들어간다.
    private func cardRow(_ plan: Plan) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: plan) {
                ScheduleCard(plan: plan)
            }
            .buttonStyle(.plain)
            // 메뉴는 카드의 `accessibilityElement(children: .combine)`에 삼켜져 VoiceOver 로는
            // 닿지 않는다. 로터의 동작으로 같은 길을 낸다.
            .accessibilityAction(named: "수정") { path = [plan] }
            .accessibilityAction(named: "삭제") { deleteTarget = plan }

            menu(for: plan)
        }
        // 지우는 동안 다시 누르지 못하게 한다 — 두 번째 요청은 404 로 돌아와 "실패"로 보인다.
        .disabled(deletingID == plan.id || revertingID == plan.id)
        .opacity(deletingID == plan.id || revertingID == plan.id ? 0.4 : 1)
        .overlay {
            if deletingID == plan.id || revertingID == plan.id {
                ProgressView().tint(.deepGreen)
            }
        }
    }

    private func menu(for plan: Plan) -> some View {
        Menu {
            // 시안의 "수정"이 어디로 가는지 지시가 없다. 상세가 편집을 모두 안고 있으므로
            // (일정 순서·장소·메모·제목) 그리로 보낸다 — 카드를 탭한 것과 같은 목적지다.
            Button("수정", systemImage: "pencil") { path = [plan] }
            // 시안에 없는 항목이다. 확정이 한 방향뿐이면 잘못 누른 플랜이 플랜 탭에서
            // 영영 사라지므로 되돌아갈 길을 낸다.
            Button("플랜으로 되돌리기", systemImage: "arrow.uturn.backward") {
                Task { await revert(plan) }
            }
            Button("삭제", systemImage: "trash", role: .destructive) { deleteTarget = plan }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .rotationEffect(.degrees(90))
                .foregroundStyle(.white)
                // 밝은 사진 위에서도 보이도록
                .shadow(color: .black.opacity(0.35), radius: 3)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("\(plan.title) 메뉴")
        .padding(.trailing, 8)
        .padding(.top, 8)
    }

    // MARK: - 상태 표시

    private var emptyText: String {
        selectedTab == .upcoming ? "예정된 일정이 없어요" : "지난 일정이 없어요"
    }

    private func message(_ text: String, isLoading: Bool) -> some View {
        VStack(spacing: 10) {
            if isLoading { ProgressView().tint(.deepGreen) }
            Text(text)
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var failedRow: some View {
        VStack(spacing: 14) {
            message("일정을 불러오지 못했어요", isLoading: false)
            Button("다시 시도") { Task { await load() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
    }

    // MARK: - 데이터

    /// 지난/예정은 저장하지 않고 종료일로 가른다 — 날짜만 고치면 카드가 그대로 옮겨간다
    /// (`Plan.isPast()`, 플랜 탭과 같은 규칙).
    private var visiblePlans: [Plan] {
        guard case .loaded(let plans) = state else { return [] }
        return plans.filter { selectedTab == .past ? $0.isPast() : !$0.isPast() }
    }

    private func load() async {
        state = .loading
        do {
            // 일정 탭은 **확정된 것만** 본다 — 초안은 플랜 탭에 남는다
            // ("플랜은 초안이고, 일정에 추가하면 확정된다").
            state = .loaded(try await planService.fetchPlans().filter { !$0.isDraft })
        } catch {
            state = .failed
        }
    }

    /// 확정을 풀어 플랜 탭으로 돌려보낸다. 서버가 성공한 뒤에만 목록에서 뺀다.
    private func revert(_ plan: Plan) async {
        revertingID = plan.id
        do {
            try await planService.setPlanConfirmed(id: plan.id, false)
            if case .loaded(var plans) = state {
                plans.removeAll { $0.id == plan.id }
                state = .loaded(plans)
            }
            UIAccessibility.post(notification: .announcement, argument: "플랜으로 되돌렸어요")
        } catch {
            revertError = (error as? PlanServiceError)?.errorDescription
                ?? "네트워크 상태를 확인하고 다시 시도해 주세요."
        }
        revertingID = nil
    }

    /// 상세에서 저장한 결과를 목록에도 반영한다.
    ///
    /// ⚠️ `days`는 비우되 **`daySummaries`는 손대지 않는다.** 저장 응답에는 요약이 없어
    /// (요약은 목록 응답에만 실린다) 덮어쓰면 카드의 DAY 줄이 통째로 사라진다.
    /// 대신 저장된 `days`로 요약을 다시 만들어 카드가 곧바로 새 동선을 보여 주게 한다.
    private func planSaved(_ saved: Plan) {
        guard case .loaded(var plans) = state,
              let index = plans.firstIndex(where: { $0.id == saved.id })
        else { return }

        var summary = saved
        summary.daySummaries = saved.days.map {
            PlanDaySummary(date: $0.date, placeNames: $0.stops.map(\.place.name))
        }
        summary.fallbackImageURL = saved.days
            .flatMap(\.stops)
            .compactMap(\.place.imageURL)
            .first ?? plans[index].fallbackImageURL
        summary.days = []
        plans[index] = summary
        state = .loaded(plans)
    }

    private func delete(_ plan: Plan) async {
        deletingID = plan.id
        deleteTarget = nil
        do {
            try await planService.deletePlan(id: plan.id)
            if case .loaded(var plans) = state {
                plans.removeAll { $0.id == plan.id }
                state = .loaded(plans)
            }
            // 카드가 사라지는 것 말고는 결과를 알릴 화면이 없다.
            UIAccessibility.post(notification: .announcement, argument: "일정을 삭제했어요")
        } catch {
            deleteError = (error as? PlanServiceError)?.errorDescription
                ?? "네트워크 상태를 확인하고 다시 시도해 주세요."
        }
        deletingID = nil
    }
}

#Preview("목 데이터") {
    ScheduleView()
        .environment(\.planService, MockPlanService())
}

#Preview("일정 없음") {
    ScheduleView()
        .environment(\.planService, EmptyPlanService())
}

#Preview("불러오기 실패") {
    ScheduleView()
        .environment(\.planService, FailingPlanService())
}
