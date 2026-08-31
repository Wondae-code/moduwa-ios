import SwiftUI

struct PlanView: View {
    @Environment(\.planService) private var planService
    @Environment(SessionStore.self) private var session
    /// 링크·코드로 들어온 초대를 여기서 수락한다 — 목록 상태와 `planService` 가 여기 있다.
    @Environment(\.inviteCoordinator) private var invites
    /// 합류 알림을 눌러 열어야 할 플랜.
    @Environment(\.pushRouter) private var pushRouter
    /// 앱이 포그라운드로 돌아오면 목록을 다시 받는다 — 낡은 판을 보는 시간을 줄여 저장 충돌
    ///  확률을 낮춘다(서버 "플랜 공동 편집" 권장). 공유 플랜의 다른 멤버 변경도 곧 보인다.
    @Environment(\.scenePhase) private var scenePhase

    @State private var state: PlanListState = .loading
    /// 초대 코드 입력 시트.
    @State private var isJoiningByCode = false
    /// 새 플랜을 만든 직후 그 상세로 보내려면 목적지를 코드로 밀어 넣어야 한다 —
    /// 플로우가 닫히는 자리에는 누를 `NavigationLink`가 없다.
    ///
    /// **`[Plan]`이 아니라 `NavigationPath`인 이유**: 상세에서 장소·후기로도 이어진다.
    /// 배열 경로는 원소 타입 하나만 받아, 다른 타입을 미는 링크는 눌러도 조용히 아무 일도
    /// 일어나지 않는다(2026-08-16에 장소 상세가 그렇게 막혔다).
    @State private var path = NavigationPath()

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
                    path = NavigationPath([created])
                },
                // 서버가 지운 뒤에만 목록에서 뺀다. 실패하면 카드는 그대로 남고 목록이 다시 시도할 수 있다
                // — 먼저 지웠다가 되돌리면 사라졌던 카드가 되살아나 무엇이 참인지 알 수 없어진다.
                onDeletePlan: { plan in
                    try await planService.deletePlan(id: plan.id)
                    guard case .loaded(var plans) = state else { return }
                    plans.removeAll { $0.id == plan.id }
                    state = .loaded(plans)
                },
                // ⚠️ **목록에서 온 플랜으로 바로 저장하면 안 된다** — `savePlan` 은 PUT 으로 본문을
                //  통째로 갈아 끼우는데 목록의 `days` 는 빈 배열이라 서버의 일정이 지워진다.
                //  팀만 고치는 것이라도 상세를 먼저 받아 온전한 플랜에 얹는다.
                onSaveParty: { plan, party in
                    var target = try await planService.fetchPlan(id: plan.id)
                    target.party = party
                    let saved = try await planService.savePlan(target, authorNm: nil)
                    guard case .loaded(var plans) = state,
                          let index = plans.firstIndex(where: { $0.id == saved.id })
                    else { return }
                    // 목록 카드는 일정을 쓰지 않는다 — 요약은 그대로 두고 본문만 비운다.
                    var summary = saved
                    summary.days = []
                    summary.daySummaries = plans[index].daySummaries
                    summary.fallbackImageURL = plans[index].fallbackImageURL
                    plans[index] = summary
                    state = .loaded(plans)
                },
                // 확정되면 이 플랜은 일정 탭으로 넘어간다 — 플랜 탭 목록에서는 뺀다.
                // 서버가 성공한 뒤에만 뺀다: 먼저 지웠다가 실패하면 사라진 카드가 되살아나
                // 무엇이 참인지 알 수 없어진다(삭제와 같은 규칙).
                onConfirmPlan: { plan in
                    try await planService.setPlanConfirmed(id: plan.id, true)
                    guard case .loaded(var plans) = state else { return }
                    plans.removeAll { $0.id == plan.id }
                    state = .loaded(plans)
                },
                // 편집자가 상세에서 플랜을 나갔다 — 서버는 이미 지웠고, 목록에서만 뺀다.
                onPlanLeft: { planId in
                    guard case .loaded(var plans) = state else { return }
                    plans.removeAll { $0.id == planId }
                    state = .loaded(plans)
                },
                onJoinByCode: { isJoiningByCode = true }
            )
        }
        .task { await load() }
        // 링크로 코드가 도착하면(RootView 가 채운다) 여기서 수락한다.
        .task(id: invites.pendingCode) { await processPendingInvite() }
        // 합류 알림에서 왔다. 목록에 있든 없든 아이디로 받아 와 상세로 민다.
        //  ⚠️ `task(id:)` 인 이유는 초대 코드와 같다 — 종료 상태에서 알림으로 열리면 값이
        //  이 뷰보다 먼저 담겨 변화 이벤트가 오지 않는다.
        .task(id: pushRouter.pendingPlanID) { await openPushedPlan() }
        // 로그인·로그아웃이 일어나면 목록을 다시 받는다. 로그아웃한 기기는 **비어야** 하고,
        //  로그인한 직후에는 곧바로 보여야 한다 — 탭을 나갔다 와야 보이면 안 된다.
        //  로그인 뒤에는 대기 중이던 초대도 이어서 수락한다.
        .onChange(of: session.phase) {
            Task {
                await load()
                await processPendingInvite()
            }
        }
        // 포그라운드 복귀 시 재조회(⑤). onChange 는 전이에만 불려 콜드런치에서 중복 로드는 없다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .loaded = state { Task { await load() } }
        }
        .sheet(isPresented: $isJoiningByCode) {
            PlanJoinByCodeView(onJoined: { result in Task { await applyJoined(result) } })
        }
        .alert("함께하기", isPresented: Binding(
            get: { invites.notice != nil }, set: { if !$0 { invites.notice = nil } })
        ) {
            Button("확인", role: .cancel) { invites.notice = nil }
        } message: {
            Text(invites.notice ?? "")
        }
    }

    /// 합류 알림에서 온 플랜을 상세로 민다.
    ///
    /// 실패하면 **조용히 넘긴다** — 대개 그 사이에 지워졌거나 내가 나온 플랜이고, 알림을
    /// 눌렀더니 오류창이 뜨는 것보다 아무 일도 없는 편이 낫다.
    private func openPushedPlan() async {
        guard let id = pushRouter.pendingPlanID else { return }
        // ⚠️ **값을 먼저 비우지 않는다** — `task(id:)` 는 id 가 바뀌면 돌던 작업을 취소한다
        //  (게시글 쪽에서 실측한 함정). 받아 온 뒤에 비운다.
        guard session.account != nil else { return }
        let plan = try? await planService.fetchPlan(id: id)
        pushRouter.pendingPlanID = nil
        if let plan { path.append(plan) }
    }

    /// 대기 중인 초대 코드를 수락한다(유니버설 링크 경로).
    /// 로그인 전이면 로그인 창을 띄우고 코드는 남겨 둔다 — 로그인 뒤 `phase` 변화로 다시 온다.
    private func processPendingInvite() async {
        guard let code = invites.pendingCode else { return }
        guard session.account != nil else {
            session.prompt = .plan
            return
        }
        invites.pendingCode = nil
        do {
            let result = try await planService.acceptInvite(code: code)
            await applyJoined(result)
        } catch {
            invites.notice = (error as? LocalizedError)?.errorDescription ?? "초대를 수락하지 못했어요."
        }
    }

    /// 수락 성공을 목록·안내에 반영한다. 참여한 플랜이 목록에 나타나도록 다시 받는다.
    private func applyJoined(_ result: InviteAcceptance) async {
        invites.notice = result.alreadyMember
            ? "이미 ‘\(result.title)’에 참여 중이에요."
            : "‘\(result.title)’에 함께하게 됐어요."
        await load()
    }

    private func load() async {
        state = .loading
        do {
            // 플랜 탭은 **초안만** 본다 — 확정된 것은 일정 탭으로 넘어간다
            // ("플랜은 초안이고, 일정에 추가하면 확정된다").
            state = .loaded(try await planService.fetchPlans().filter(\.isDraft))
        } catch PlanServiceError.loginRequired, PlanServiceError.sessionExpired {
            state = .signedOut
        } catch {
            state = .failed
        }
    }
}

#Preview("목 데이터") {
    PlanView()
        .environment(\.planService, MockPlanService())
        .environment(SessionStore(service: MockAuthService()))
}

#Preview("플랜 없음") {
    PlanView()
        .environment(\.planService, EmptyPlanService())
        .environment(SessionStore(service: MockAuthService()))
}

#Preview("불러오기 실패") {
    PlanView()
        .environment(\.planService, FailingPlanService())
        .environment(SessionStore(service: MockAuthService()))
}
