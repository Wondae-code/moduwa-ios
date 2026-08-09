import SwiftUI

struct PlanView: View {
    @Environment(\.planService) private var planService

    @State private var state: PlanListState = .loading
    /// 새 플랜을 만든 직후 그 상세로 보내려면 목적지를 코드로 밀어 넣어야 한다 —
    /// 플로우가 닫히는 자리에는 누를 `NavigationLink`가 없다.
    @State private var path: [Plan] = []

    var body: some View {
        NavigationStack(path: $path) {
            PlanListView(
                state: state,
                onRetry: { Task { await load() } },
                // 상세에서 저장한 결과를 목록에도 반영한다. 목록을 다시 받지 않는 이유는
                // 서버가 저장 응답으로 갱신된 플랜을 그대로 돌려주기 때문이다 — 왕복이 한 번 준다.
                onPlanSaved: { saved in
                    guard case .loaded(var plans) = state,
                          let index = plans.firstIndex(where: { $0.id == saved.id })
                    else { return }
                    // 목록 카드는 일정을 쓰지 않지만, days를 남겨 두면 목록에서 넘어온 플랜과
                    // 상세를 받아 온 플랜이 섞여 어느 쪽인지 알 수 없게 된다(상세가 늘 다시 받는다).
                    var summary = saved
                    summary.days = []
                    plans[index] = summary
                    state = .loaded(plans)
                },
                // 서버 저장이 끝난 뒤에만 불린다. 목록을 다시 받지 않고 직접 꽂는 이유는
                // 상세에서 돌아왔을 때 방금 만든 플랜이 목록에 없으면 사라진 것처럼 보이기 때문이다.
                onPlanCreated: { created in
                    if case .loaded(var plans) = state {
                        // 목록 카드는 일정을 쓰지 않는다. `days`를 남기면 목록에서 온 플랜과
                        // 상세를 받아 온 플랜이 섞여 어느 쪽인지 알 수 없게 된다.
                        var summary = created
                        summary.days = []
                        // 다음 새로고침에서 서버가 정한 자리로 옮겨간다 — 그전까지는 맨 위가 자연스럽다.
                        plans.insert(summary, at: 0)
                        state = .loaded(plans)
                    }
                    path = [created]
                },
                // 서버가 지운 뒤에만 목록에서 뺀다. 실패하면 카드는 그대로 남고 목록이 다시 시도할 수 있다
                // — 먼저 지웠다가 되돌리면 사라졌던 카드가 되살아나 무엇이 참인지 알 수 없어진다.
                onDeletePlan: { plan in
                    try await planService.deletePlan(id: plan.id)
                    guard case .loaded(var plans) = state else { return }
                    plans.removeAll { $0.id == plan.id }
                    state = .loaded(plans)
                }
            )
        }
        .task { await load() }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await planService.fetchPlans())
        } catch {
            state = .failed
        }
    }
}

#Preview("목 데이터") {
    PlanView()
        .environment(\.planService, MockPlanService())
}

#Preview("플랜 없음") {
    PlanView()
        .environment(\.planService, EmptyPlanService())
}

#Preview("불러오기 실패") {
    PlanView()
        .environment(\.planService, FailingPlanService())
}
