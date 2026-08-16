import SwiftUI

/// 목록 자리에 무엇을 그릴지.
///
/// 헤더("내 플랜")와 "새 플랜 계획하기" 버튼은 **어느 상태에서도 남는다** — 로딩이나 오류 때문에
/// 화면 제목까지 사라지면 사용자는 지금 어느 탭에 있는지 알 수 없다.
enum PlanListState {
    case loading
    case failed
    /// 빈 배열이면 "아직 플랜이 없음"이다 (오류와 구분된다)
    case loaded([Plan])
}

/// 플랜 목록 — Figma "02. 플랜"(391:232)
///
/// 카드가 두 종류다. 오늘을 포함하거나 아직 오지 않은 여행은 사진을 가진 큰 카드(631:229)로,
/// 이미 지나간 여행은 사진 없는 회색 카드(507:98)로 그린다. 판정은 `Plan.isPast()` 하나뿐이라
/// 날짜만 고치면 카드 모양이 그대로 되살아난다(시안 "날짜 수정시 활성화" 639:329와 같은 동작).
struct PlanListView: View {
    let state: PlanListState
    var onRetry: () -> Void = {}
    /// 상세에서 저장이 끝나면 갱신된 플랜이 올라온다 — 목록이 옛 값을 들고 있지 않게 한다.
    var onPlanSaved: (Plan) -> Void = { _ in }
    /// 새 플랜 플로우가 서버 저장까지 마쳤을 때. 호출부가 목록에 꽂고 상세로 넘긴다.
    var onPlanCreated: (Plan) -> Void = { _ in }
    /// 확인까지 받은 뒤의 삭제. **성공할 때까지 기다린다** — 카드를 먼저 지우고 뒤에서 요청하면
    /// 실패했을 때 목록에는 없는데 서버에는 남은 플랜이 생긴다.
    var onDeletePlan: (Plan) async throws -> Void = { _ in }
    /// "팀 수정" 저장. **성공할 때까지 기다린다** — 시트가 실패를 띄우고 열린 채 남아야 한다.
    var onSaveParty: (Plan, TravelParty) async throws -> Void = { _, _ in }
    /// "일정에 추가" — 초안을 확정으로 올린다. 확인까지 받은 뒤에 불린다.
    var onConfirmPlan: (Plan) async throws -> Void = { _ in }

    @State private var isCreatingPlan = false
    /// 삭제 확인 대상. nil 이면 확인 창이 닫혀 있다.
    @State private var deleteTarget: Plan?
    @State private var deletingID: Plan.ID?
    @State private var deleteError: String?
    /// "팀 수정" 대상. nil 이면 시트가 닫혀 있다.
    @State private var partyTarget: Plan?
    /// "일정에 추가" 확인 대상.
    @State private var confirmTarget: Plan?
    @State private var confirmingID: Plan.ID?
    @State private var confirmError: String?

    /// 시안은 카드를 393폭 안에서 321로 두어 좌우 36을 남긴다 — 다른 화면(24)과 다르다.
    private static let sideMargin: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                Group {
                    switch state {
                    case .loading:
                        loadingRow
                    case .failed:
                        errorRow
                    case .loaded(let plans) where plans.isEmpty:
                        emptyRow
                    case .loaded(let plans):
                        LazyVStack(spacing: 26) {
                            ForEach(plans) { plan in
                                PlanCard(
                                    plan: plan,
                                    isDeleting: deletingID == plan.id || confirmingID == plan.id,
                                    onRequestDelete: { deleteTarget = plan },
                                    onEditParty: { partyTarget = plan },
                                    onAddToSchedule: { confirmTarget = plan })
                            }
                        }
                    }
                }
                .padding(.horizontal, Self.sideMargin)
                .padding(.top, 29)
                // 플로팅 버튼에 마지막 카드가 가리지 않도록 스크롤 끝에 여유를 준다
                .padding(.bottom, 120)
            }
        }
        .background(Color.appBackground)
        .overlay(alignment: .bottom) { createPlanOverlay }
        .navigationDestination(for: Plan.self) {
            PlanDetailView(plan: $0, onPlanSaved: onPlanSaved)
        }
        // 6단계 플로우는 제 진행 바와 뒤로 버튼을 들고 있다 — 시트로 열면 그 위에 시스템 손잡이가
        // 겹치고 스와이프로 중간에 닫혀, 어디까지 답했는지 모르는 채 사라진다.
        .fullScreenCover(isPresented: $isCreatingPlan) {
            PlanCreateFlowView(onCreated: onPlanCreated)
        }
        // 되돌릴 수 없는 삭제라 한 번 묻는다. 실행 취소를 두지 않는 이유는 서버에 휴지통이 없어서다
        // — 앱에만 되돌리기를 두면 앱을 끄는 순간 사라지는 약속이 된다.
        //
        // `confirmationDialog`이 아니라 `alert`인 이유: iOS 26 의 확인 시트는 누른 자리에 붙는
        // 말풍선으로 뜨는데, 카드가 화면 위쪽에 있으면 말풍선이 아래로 흘러 "취소"가 잘린다.
        // 경고창은 늘 화면 가운데라 두 선택지가 언제나 함께 보인다.
        .alert(
            "이 플랜을 삭제할까요?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            presenting: deleteTarget
        ) { plan in
            Button("삭제", role: .destructive) { Task { await delete(plan) } }
            Button("취소", role: .cancel) {}
        } message: { plan in
            Text("‘\(plan.title)’의 일정과 메모가 함께 지워지고 되돌릴 수 없어요.")
        }
        .sheet(item: $partyTarget) { plan in
            PlanPartyEditView(currentParty: plan.party) { party in
                try await onSaveParty(plan, party)
            }
        }
        // 확정하면 이 카드가 플랜 탭에서 사라져 일정 탭으로 옮겨간다 — 눌러 놓고 어디 갔는지
        //  찾게 되는 일이 없도록 한 번 묻고, 어디로 가는지 문장으로 알린다.
        .alert(
            "일정에 추가할까요?",
            isPresented: Binding(get: { confirmTarget != nil }, set: { if !$0 { confirmTarget = nil } }),
            presenting: confirmTarget
        ) { plan in
            Button("추가") { Task { await confirm(plan) } }
            Button("취소", role: .cancel) {}
        } message: { plan in
            Text("‘\(plan.title)’이 확정되어 일정 탭으로 옮겨져요. 일정에서 다시 플랜으로 되돌릴 수 있어요.")
        }
        .alert("일정에 추가하지 못했어요", isPresented: Binding(
            get: { confirmError != nil }, set: { if !$0 { confirmError = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(confirmError ?? "")
        }
        .alert("플랜을 삭제하지 못했어요", isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func confirm(_ plan: Plan) async {
        confirmingID = plan.id
        confirmTarget = nil
        do {
            try await onConfirmPlan(plan)
            // 카드가 사라지는 것 말고는 결과를 알릴 화면이 없다 — 어디로 갔는지까지 말해 준다.
            UIAccessibility.post(notification: .announcement, argument: "일정에 추가했어요")
        } catch {
            confirmError = (error as? PlanServiceError)?.errorDescription
                ?? "네트워크 상태를 확인하고 다시 시도해 주세요."
        }
        confirmingID = nil
    }

    private func delete(_ plan: Plan) async {
        deletingID = plan.id
        deleteTarget = nil
        do {
            try await onDeletePlan(plan)
            // 카드가 사라지는 것 말고는 결과를 알릴 화면이 없다 — 스크린리더에는 그 변화가 보이지 않는다.
            UIAccessibility.post(notification: .announcement, argument: "플랜을 삭제했어요")
        } catch {
            deleteError = (error as? PlanServiceError)?.errorDescription
                ?? "네트워크 상태를 확인하고 다시 시도해 주세요."
        }
        deletingID = nil
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("내 플랜")
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .tracking(-0.4)

            Spacer(minLength: 0)

            // 메뉴는 아직 목적지가 없다 — 다른 화면의 준비 중 버튼과 같은 방식으로 알린다.
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)
        }
    }

    /// 시안은 목록 위에 버튼을 띄우고 뒤쪽을 흐린다(Progressive Blur 642:800, 393×134).
    /// SwiftUI에 점진적 블러가 없어 배경색으로 페이드하는 그라디언트로 대신한다 —
    /// 목적이 "버튼 뒤 글자가 버튼과 겹쳐 읽히지 않게" 하는 것이라 페이드로 충분하다.
    private var createPlanOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color.appBackground.opacity(0), Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 134)
            .allowsHitTesting(false)

            Button {
                isCreatingPlan = true
            } label: {
                Text("+ 새 플랜 계획하기")
                    .font(.notoSans(16, .bold, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 234, height: 46)
                    .background(Color.moduwaGreen, in: Capsule())
                    .shadow(color: Color.deepGreen.opacity(0.15), radius: 8, y: 3)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 로딩 · 오류 · 빈 상태

    /// 스피너만 두면 스크린리더에는 아무것도 전달되지 않는다 — 문구를 함께 둔다
    /// (장소 후기 화면과 같은 규칙).
    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.deepGreen)
            Text("플랜을 불러오는 중이에요")
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("플랜을 불러오는 중이에요")
    }

    private var errorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("플랜을 불러오지 못했어요")
                .font(.notoSans(15, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)

            Text("네트워크 상태를 확인하고 다시 시도해 주세요")
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                Text("다시 시도")
                    .font(.notoSans(14, .bold, relativeTo: .subheadline))
                    .tracking(-0.4)
                    .foregroundStyle(Color.deepGreen)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(Color.appBackground))
                    .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("플랜 다시 불러오기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 서버에 플랜이 없는 상태. 여기서 목 데이터를 채우지 않는다 —
    /// 만든 적 없는 여행이 자기 목록에 있는 것처럼 보이는 편이 빈 화면보다 나쁘다.
    private var emptyRow: some View {
        VStack(spacing: 8) {
            Text("아직 만든 플랜이 없어요")
                .font(.notoSans(16, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)

            // 아래 "+ 새 플랜 계획하기"가 앞으로의 경로라는 걸 알려 준다.
            Text("아래 ‘새 플랜 계획하기’로 여행 일정을 만들면\n날짜별 장소와 메모를 여기에 모아 볼 수 있어요")
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 카드

private struct PlanCard: View {
    let plan: Plan
    var isDeleting = false
    var onRequestDelete: () -> Void = {}
    var onEditParty: () -> Void = {}
    var onAddToSchedule: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: plan) {
                if plan.isPast() {
                    PastPlanCard(plan: plan)
                } else {
                    UpcomingPlanCard(plan: plan)
                }
            }
            .buttonStyle(.plain)
            // 메뉴 버튼은 카드의 `accessibilityElement(children: .combine)`에 삼켜져 VoiceOver 로는
            // 닿지 않는다. 로터의 동작으로 같은 길을 낸다.
            .accessibilityAction(named: "삭제", onRequestDelete)

            // 메뉴는 링크의 **형제**다. 카드 안에 넣으면 ⋮ 를 누른 손가락이 상세로도 들어간다.
            menu
        }
        // 지우는 동안 다시 누르지 못하게 한다 — 두 번째 요청은 404 로 돌아와 "실패"로 보인다.
        .disabled(isDeleting)
        .opacity(isDeleting ? 0.4 : 1)
        .overlay {
            if isDeleting { ProgressView().tint(.deepGreen) }
        }
    }

    /// 시안 553:131 — "팀 수정" / "일정에 추가" / 삭제.
    ///
    /// 지난 카드는 회색 배경 위라 흰 ⋮ 가 보이지 않는다.
    /// ⚠️ 글리프는 **세로**다(시안 아이콘 642:356 이 3×16). `ellipsis` 는 가로라 90° 돌려 쓴다.
    private var menu: some View {
        Menu {
            // 새 플랜 플로우 1/6 에서 고른 동반자 정보를 다시 손보는 자리
            //  (`TravelParty` 주석의 "목록 카드의 '팀 수정'").
            Button("팀 수정", systemImage: "person.2", action: onEditParty)
            Button("일정에 추가", systemImage: "calendar.badge.plus", action: onAddToSchedule)
            Button("삭제", systemImage: "trash", role: .destructive, action: onRequestDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .rotationEffect(.degrees(90))
                .foregroundStyle(plan.isPast() ? Color.textSecondary : .white)
                .shadow(color: .black.opacity(plan.isPast() ? 0 : 0.3), radius: 2)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("\(plan.title) 메뉴")
        .padding(.trailing, 8)
        .padding(.top, 8)
    }
}

/// 오늘 이후(또는 오늘 포함) 여행 — 사진이 카드를 꽉 채우고 제목·날짜가 그 위에 얹힌다.
private struct UpcomingPlanCard: View {
    let plan: Plan

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cover

            // 사진 위 흰 글씨의 가독성을 사진에 맡기지 않는다 — 밝은 사진에서도 읽혀야 한다.
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 103)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Text(plan.title)
                    .font(.notoSans(18, .bold, relativeTo: .headline))
                    .tracking(-0.4)

                Text(plan.dateRangeText)
                    .font(.notoSans(14, .regular, relativeTo: .subheadline))
                    .tracking(-0.4)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.leading, 27)
            .padding(.bottom, 22)
            .padding(.trailing, 27)
        }
        .frame(height: 243)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.title), \(plan.dateRangeText)")
    }

    private var cover: some View {
        Group {
            // 표지가 없으면 첫 장소 사진으로 폴백한다(`Plan.cardImageURL`) — 일정 탭 카드와 같은 값.
            if let url = plan.cardImageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.photoPlaceholder
                }
            } else {
                Color.photoPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// 지나간 여행 — 시안은 사진을 빼고 무채색 카드에 제목·날짜만 남긴다.
///
/// 시안에는 ⋮ 가 앞으로 올 여행 카드에만 있지만 여기에도 둔다 — 없으면 지난 여행은 영영 지울 수
/// 없고, 목록은 시간이 갈수록 손댈 수 없는 카드로만 쌓인다.
private struct PastPlanCard: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.title)
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)

            Text(plan.dateRangeText)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.4)
        }
        .foregroundStyle(Color.textPrimary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 28)
        // ⋮ 가 앉을 자리를 비워 둔다 — 긴 제목이 버튼 밑으로 들어가면 둘 다 읽기 어려워진다.
        .padding(.trailing, 56)
        .padding(.top, 18)
        .padding(.bottom, 19)
        .background(Color.cardStroke, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.title), \(plan.dateRangeText), 지난 여행")
    }
}

/// 목적지가 아직 없는 버튼 — 눌러도 아무 일이 없으면 고장으로 읽히므로 준비 중임을 알린다.
/// 커스텀 토스트가 아니라 기본 popover 를 쓰는 이유는 VoiceOver 가 내용을 읽어 주기 때문이다
/// (앱의 다른 준비 중 버튼도 같은 방식이다).
///
/// 일정 탭 헤더의 햄버거도 같은 처지라 파일 전용을 풀었다.
struct PlanPlaceholderButton<Label: View>: View {
    let notice: String
    @ViewBuilder let label: () -> Label

    @State private var showsNotice = false

    var body: some View {
        Button { showsNotice = true } label: { label() }
            .buttonStyle(.plain)
            .popover(isPresented: $showsNotice) {
                Text(notice)
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Color.textPrimary)
                    .padding(16)
                    // 없으면 iPhone(compact)에서 popover가 시트로 바뀐다
                    .presentationCompactAdaptation(.popover)
            }
    }
}

#Preview("목록") {
    NavigationStack {
        PlanListView(state: .loaded(MockData.plans))
    }
}

#Preview("플랜 없음") {
    NavigationStack {
        PlanListView(state: .loaded([]))
    }
}

#Preview("불러오기 실패") {
    NavigationStack {
        PlanListView(state: .failed)
    }
}

#Preview("큰 글자 (AX3)") {
    NavigationStack {
        PlanListView(state: .loaded([]))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
