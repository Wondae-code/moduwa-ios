import SwiftUI

/// 새 플랜 만들기 6단계 — Figma "02-2. 새 플랜 플로우"(372:409 · 391:96 · 519:1219 · 519:1343)와
/// 4/6~6/6 기획 스케치(532:169).
///
/// 목록의 "+ 새 플랜 계획하기"에서 전체 화면으로 열린다. 6/6에서 "혼자 짜볼래요"를 누르면
/// 그때 **한 번만** 서버에 저장하고(`PUT /v1/plans/:id`) 방금 만든 플랜 상세로 넘긴다 —
/// 단계마다 저장하면 중간에 그만둔 사용자의 목록에 반쯤 만든 플랜이 남는다.
struct PlanCreateFlowView: View {
    /// 저장에 성공했을 때만 불린다. 호출부가 목록에 꽂고 상세로 이동한다.
    var onCreated: (Plan) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.planService) private var planService
    @AppStorage(ReviewAuthorStore.nicknameKey) private var savedNickname = ""

    @State private var step: PlanCreateStep = .party
    @State private var draft = PlanDraft()

    /// 4/6·5/6 선택지. 못 받으면 두 단계를 통째로 건너뛴다 — 문구를 앱에서 지어낼 수 없다.
    @State private var options = PlanOptions.empty
    @State private var optionsFailed = false

    @State private var isSaving = false
    /// 저장 실패 사유 — 서버가 준 한국어 문장을 그대로 띄운다
    @State private var saveError: String?
    /// 이 기기의 첫 저장이라 서버가 표시 이름을 요구한 경우. 지어낸 이름을 보내지 않고 직접 묻는다.
    @State private var needsNickname = false
    @State private var nicknameInput = ""
    @FocusState private var nicknameFocused: Bool

    /// 추천 코스를 받아 오는 중.
    @State private var isRecommending = false
    /// 받아 왔지만 **알릴 것이 있어** 아직 담지 않은 코스.
    ///
    /// 예산을 골랐는데 다른 가격대 숙소가 왔거나 칸이 비었으면(`notes`) 그대로 담아 버리지
    /// 않는다 — 사용자는 앱이 자기 선택을 무시했다고 읽는다. 무엇이 달라졌는지 보여 주고
    /// 한 번 더 누르게 한다. 알릴 것이 없으면 바로 담는다.
    @State private var pendingCourse: RecommendedCourse?

    var body: some View {
        VStack(spacing: 0) {
            PlanCreateHeader(step: step, onBack: goBack)
                .padding(.top, 4)

            PlanCreateQuestion(text: step.question)
                .padding(.top, 34)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer
        }
        .background(Color.appBackground)
        .task { await loadOptions() }
        // 단계가 바뀌면 화면이 통째로 바뀐 것과 같다 — 포커스를 새 화면으로 옮기며 질문을 읽어 준다.
        .onChange(of: step) { _, new in
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "\(PlanCreateStep.total)단계 중 \(new.rawValue)단계. \(new.question)")
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        switch step {
        case .party:
            scrolling { PlanPartyStep(party: $draft.party) }
        case .region:
            scrolling { PlanRegionStep(region: $draft.region) }
        case .dates:
            // 달력이 스스로 스크롤한다 (요약 줄과 구분선은 위에 고정된다)
            PlanDateRangeCalendar(startDate: $draft.startDate, endDate: $draft.endDate)
        case .themes:
            scrolling {
                if options.themes.isEmpty {
                    optionsNotice
                } else {
                    PlanThemeStep(
                        themes: options.themes,
                        selected: $draft.themes,
                        avoidsCrowds: $draft.avoidsCrowds)
                }
            }
        case .budget:
            scrolling {
                if options.budgets.isEmpty {
                    optionsNotice
                } else {
                    PlanBudgetStep(budgets: options.budgets, selected: $draft.budget)
                }
            }
        case .finish:
            finishStep
        }
    }

    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.top, 42)
                .padding(.bottom, 24)
        }
    }

    /// 선택지를 못 받은 단계. 그려 줄 문구가 없으니 다시 시도하거나 건너뛰는 수밖에 없다.
    private var optionsNotice: some View {
        PlanCreateNotice(
            message: "선택지를 불러오지 못했어요.\n건너뛰고 나중에 상세에서 정할 수 있어요.",
            retryLabel: "다시 시도"
        ) {
            Task { await loadOptions() }
        }
        .padding(.top, 40)
    }

    // MARK: - 6/6

    /// 스케치는 질문 아래에 "네!"와 "혼자 짜볼래요" 두 버튼만 둔다 — 완료/건너뛰기가 없다.
    private var finishStep: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            if let saveError {
                PlanCreateNotice(message: saveError)
                    .padding(.bottom, 4)
            }

            if needsNickname { nicknameField }

            Button {
                Task {
                    if pendingCourse == nil { await recommend() } else { await saveCourse() }
                }
            } label: {
                ZStack {
                    Text(pendingCourse == nil ? "네!" : "이대로 담을게요")
                        .font(.notoSans(16, .bold, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .opacity(isRecommending ? 0 : 1)
                    if isRecommending { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 55)
                .background(Capsule().fill(Color.deepGreen))
            }
            .buttonStyle(.plain)
            .disabled(isSaving || isRecommending)
            .accessibilityLabel(isRecommending ? "추천 코스 만드는 중" : (pendingCourse == nil ? "네, 추천 코스 보기" : "이대로 담을게요"))
            .accessibilityHint("고르신 조건으로 하루 일정을 만들어 플랜에 담습니다")

            Button { Task { await save() } } label: {
                ZStack {
                    Text("혼자 짜볼래요")
                        .font(.notoSans(16, .bold, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(Color.deepGreen)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.deepGreen) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 55)
                .background(Capsule().fill(Color.appBackground))
                .overlay(Capsule().stroke(Color.deepGreen, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel(isSaving ? "플랜 저장 중" : "혼자 짜볼래요")
            .accessibilityHint("플랜을 만들고 상세 화면으로 넘어갑니다")
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 12)
    }

    /// 첫 저장에서만 나타난다. 지어낸 기본 이름을 보내면 서버가 이 기기의 후기 닉네임을
    /// 그 값으로 덮어쓴다(`PlanService.savePlan` 주의사항 참고).
    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("플랜에 표시될 이름", text: $nicknameInput)
                .font(.notoSans(15, .regular, relativeTo: .body))
                .foregroundStyle(Color.textPrimary)
                .tint(.deepGreen)
                .focused($nicknameFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit { Task { await save() } }
                .onChange(of: nicknameInput) {
                    if nicknameInput.count > ReviewAuthorStore.nicknameLimit {
                        nicknameInput = String(nicknameInput.prefix(ReviewAuthorStore.nicknameLimit))
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .background(Capsule().fill(Color.photoPlaceholder))
                .accessibilityLabel("플랜에 표시될 이름")

            Text("처음 한 번만 입력하면 다음 플랜에는 자동으로 채워져요")
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - 하단

    @ViewBuilder
    private var footer: some View {
        if step != .finish {
            PlanCreateFooter(hasValue: hasValue, onComplete: goNext, onSkip: skip)
        }
    }

    /// 이 단계에서 고른 값이 있는지 — "완료했어요" 노출 조건(`PlanCreateFooter` 주석 참고).
    private var hasValue: Bool {
        switch step {
        case .party: !draft.party.isEmpty
        case .region: draft.region != nil
        // 출발일만 고른 상태로 넘어가면 당일치기가 된다 — 시안에 그 표기가 없어 둘 다 요구한다.
        case .dates: draft.startDate != nil && draft.endDate != nil
        case .themes: !draft.themes.isEmpty
        case .budget: draft.budget != nil
        case .finish: false
        }
    }

    // MARK: - 이동

    private func goBack() {
        guard let previous = previousStep else {
            dismiss()
            return
        }
        withoutAnimation { step = previous }
    }

    private func goNext() {
        guard let next = nextStep else { return }
        withoutAnimation { step = next }
    }

    /// 건너뛰기는 이 단계의 값을 **비우고** 넘어간다. 앞 단계로 돌아갔다가 다시 건너뛰면
    /// 먼저 고른 값이 남아 있어서는 안 된다 — 화면에는 아무것도 안 골랐다고 보이기 때문이다.
    private func skip() {
        switch step {
        case .party: draft.party = TravelParty()
        case .region: draft.region = nil
        case .dates:
            draft.startDate = nil
            draft.endDate = nil
        case .themes:
            draft.themes = []
            draft.avoidsCrowds = false
        case .budget: draft.budget = nil
        case .finish: break
        }
        goNext()
    }

    /// 4/6·5/6은 서버 선택지가 있어야 그릴 수 있다. 못 받았으면 둘 다 지나친다
    /// (스케치의 "skip" 화살표가 4/6·5/6에서 6/6으로 건너뛰는 그 경로다).
    private var nextStep: PlanCreateStep? {
        var candidate = step
        while let next = PlanCreateStep(rawValue: candidate.rawValue + 1) {
            candidate = next
            if !isSkippedForMissingOptions(candidate) { return candidate }
        }
        return nil
    }

    private var previousStep: PlanCreateStep? {
        var candidate = step
        while let previous = PlanCreateStep(rawValue: candidate.rawValue - 1) {
            candidate = previous
            if !isSkippedForMissingOptions(candidate) { return candidate }
        }
        return nil
    }

    /// 불러오기에 **실패했을 때만** 지나친다. 아직 받는 중이면 그 단계에서 다시 시도할 수 있게 둔다.
    private func isSkippedForMissingOptions(_ candidate: PlanCreateStep) -> Bool {
        guard optionsFailed else { return false }
        return candidate == .themes || candidate == .budget
    }

    // MARK: - 선택지

    private func loadOptions() async {
        do {
            options = try await planService.fetchPlanOptions()
            optionsFailed = false
        } catch {
            optionsFailed = true
        }
    }

    // MARK: - 추천 코스

    /// 6/6 "네!" — 고른 조건으로 코스를 받아 온다.
    ///
    /// 지역은 서버가 후보를 고르는 전제라 없으면 부를 수 없다. 2/6 은 건너뛸 수 있는
    /// 단계이므로, 막지 않고 **무엇이 필요한지 알려 주고** "혼자 짜볼래요"를 남긴다.
    private func recommend() async {
        guard !isRecommending, !isSaving else { return }
        guard let region = draft.region else {
            saveError = "추천 코스를 만들려면 2단계에서 여행지를 골라 주세요."
            UIAccessibility.post(notification: .announcement, argument: saveError ?? "")
            return
        }

        isRecommending = true
        saveError = nil
        defer { isRecommending = false }

        let plan = draft.makePlan()
        do {
            let course = try await planService.recommendCourse(CourseRequest(
                regionSlug: region.courseSlug,
                startDate: plan.startDate,
                endDate: plan.endDate,
                party: draft.party.courseCodes,
                themes: draft.themes,
                budget: draft.budget,
                // 당일치기는 따로 묻지 않는다 — **날짜가 이미 답이다.** 하루짜리 여행에
                //  숙소를 고르는 것은 서버 일을 낭비하는 것이고, 저장된 플랜에 넣어 두면
                //  나중에 날짜를 늘렸을 때 낡은 값이 남는다. 요청할 때 그 자리에서 계산한다.
                dayTripOnly: Calendar.current.isDate(
                    plan.startDate, inSameDayAs: plan.endDate),
                avoidCrowds: draft.avoidsCrowds
            ))

            if let notice = course.noticeMessage {
                // 알릴 것이 있으면 한 번 보여 주고 사용자가 확인한 뒤 담는다.
                pendingCourse = course
                saveError = notice
                UIAccessibility.post(notification: .announcement, argument: notice)
            } else {
                await save(days: course.days)
            }
        } catch {
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "추천 코스를 만들지 못했어요. 잠시 후 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// 안내를 보고 그대로 담기로 한 경우.
    private func saveCourse() async {
        guard let course = pendingCourse else { return }
        await save(days: course.days)
    }

    // MARK: - 저장

    private func save(days: [PlanDay] = []) async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        nicknameFocused = false

        // 사용자가 **직접 적은** 이름만 보낸다. nil이면 서버가 기존 닉네임을 재사용한다.
        let typed = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorNm = typed.isEmpty ? nil : typed

        do {
            // 추천 코스를 받았으면 그 일정을 담아 저장한다. "혼자 짜볼래요"는 빈 채로 만든다.
            var plan = draft.makePlan()
            plan.days = days
            let saved = try await planService.savePlan(plan, authorNm: authorNm)
            // 성공한 뒤에만 기기에 남긴다 — 실패한 이름을 굳혀 두면 다시 물을 기회가 없다.
            if let authorNm { savedNickname = authorNm }
            onCreated(saved)
            // 화면이 닫히면 포커스가 옮겨가 결과를 놓치므로 직접 알린다.
            UIAccessibility.post(
                notification: .announcement,
                argument: days.isEmpty ? "플랜을 만들었어요" : "추천 코스를 담아 플랜을 만들었어요")
            dismiss()
        } catch PlanServiceError.nicknameRequired {
            isSaving = false
            // 서버가 표시 이름을 요구한다. 지어내지 않고 직접 묻는다.
            needsNickname = true
            nicknameInput = savedNickname
            nicknameFocused = true
            saveError = PlanServiceError.nicknameRequired.errorDescription
            UIAccessibility.post(notification: .announcement, argument: saveError ?? "")
        } catch {
            isSaving = false
            // URLError 등 시스템 오류의 영어 문구가 새지 않게, 서버가 준 한국어 사유만 쓴다.
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "플랜을 저장하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview("새 플랜 플로우") {
    PlanCreateFlowView()
        .environment(\.planService, MockPlanService())
}

#Preview("선택지 없음 (4·5단계 건너뜀)") {
    PlanCreateFlowView()
        .environment(\.planService, FailingPlanService())
}

#Preview("큰 글자 (AX3)") {
    PlanCreateFlowView()
        .environment(\.planService, MockPlanService())
        .environment(\.dynamicTypeSize, .accessibility3)
}
