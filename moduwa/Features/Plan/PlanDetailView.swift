import SwiftUI

/// 플랜 상세 — Figma "02-1. 플랜 상세 - 지도 & Day별 view"(509:340)
///
/// 지도가 본문이고 Day별 일정이 그 위로 올라오는 바텀시트다.
/// 손잡이를 끌거나 탭해 세 자리(지도만 / 반반 / 일정만)를 오간다 — 일정만 보는 자리가
/// 시안의 "Day별 view"(519:775)다.
struct PlanDetailView: View {
    /// 목록에서 넘어온 플랜. **`days`가 비어 있다** — 서버가 목록 응답에 일정을 싣지 않는다.
    /// 제목·날짜는 여기서 바로 그리고, 일정은 `detail`이 도착해야 나온다.
    let plan: Plan
    /// 저장이 끝나면 갱신된 플랜을 목록에 돌려준다
    var onPlanSaved: (Plan) -> Void = { _ in }

    @Environment(\.planService) private var planService
    @Environment(\.dismiss) private var dismiss
    @State private var detent: SheetDetent = .medium
    /// 드래그 중인 손가락 이동량. 놓으면 0으로 돌아가고 `detent`가 갱신된다.
    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var isAddingMemo = false
    @State private var isEditingTitle = false
    @State private var isAddingPlace = false
    /// 서버에서 받아 온 상세(일정 포함). 저장에 성공하면 서버가 돌려준 값으로 갈아 끼운다.
    @State private var detail: Plan?
    @State private var loadFailed = false
    /// 카카오맵 엔진은 레이아웃이 잡힌 뒤에 켜야 한다 — 미리 켜면 렌더링이 멈춘다.
    @State private var mapDrawn = false
    /// 시트에서 지금 맨 위에 걸린 날. 지도 핀이 이 값을 따라간다.
    /// 스크롤 도중 잠깐 nil 이 되므로 읽는 쪽에서 첫 날로 폴백한다.
    @State private var visibleDayID: PlanDay.ID?
    /// 후기를 보러 갈 장소. 별을 누르면 채워지고, 그때 후기 화면으로 밀려 올라간다.
    @State private var reviewTarget: PlanPlace?

    /// 시트가 멈추는 세 자리. 값은 본문 높이에 대한 비율이다.
    ///  시안(509:340)은 본문 662 중 시트 365(≈55%)를 기본으로 두고, "Day별 view"(519:775)는
    ///  지도를 완전히 덮는다. 지도를 온전히 보는 자리를 하나 더 둬 0 / 55 / 100 이 된다.
    ///  `collapsed`의 0은 "콘텐츠 0"이라는 뜻이고, 손잡이는 `handleHeight`만큼 남는다.
    enum SheetDetent: CaseIterable {
        case collapsed, medium, listOnly

        var fraction: CGFloat {
            switch self {
            case .collapsed: 0
            case .medium: 0.55
            case .listOnly: 1.0
            }
        }

        /// VoiceOver 로 현재 상태를 알린다 — 드래그는 스크린리더로 쓸 수 없는 조작이라
        /// 핸들은 버튼 역할을 유지하고 값으로 상태를 전달한다.
        var label: String {
            switch self {
            case .collapsed: "지도만 보기"
            case .medium: "지도와 일정 반반"
            case .listOnly: "일정만 보기"
            }
        }
    }

    /// 지도에는 **지금 보고 있는 날**의 핀만 찍는다.
    ///
    /// 여러 날을 한 번에 그리면 번호가 1부터 다시 시작하는 핀이 겹쳐 읽을 수 없다.
    /// 그렇다고 DAY 1 로 고정하면(예전 동작) DAY 2 를 읽는 동안 지도는 엉뚱한 날을 보여 준다 —
    /// 시트를 스크롤해 날이 넘어가면 지도도 따라간다(2026-08-16 사용자 요청).
    private var mappedStops: [PlanStop] {
        let day = days.first { $0.id == visibleDayID } ?? days.first
        return day?.stops ?? []
    }

    /// 제목·날짜는 상세가 오기 전에도 목록에서 받은 값으로 그린다 — 스피너만 띄우고 기다리면
    ///  이미 알고 있는 정보까지 감추게 된다.
    private var current: Plan { detail ?? plan }

    /// 일정은 상세를 받아야만 있다. `plan.days`로 폴백하지 않는다 —
    ///  목록의 빈 배열을 "일정 없음"으로 그리면 로딩 중에 잘못된 사실을 보여 주게 된다.
    private var days: [PlanDay] { detail?.days ?? [] }

    /// 담긴 장소가 하나도 없을 때 지도를 맞출 자리.
    ///
    /// 핀이 0개인 지도는 아무 데나 잡힌 회색 사각형이라 예전에는 지도를 통째로 숨겼다.
    /// 하지만 플랜에는 여행 지역이 정해져 있으므로 **"어디로 가는 계획인지"는 보여 줄 수 있다** —
    /// 갓 만든 플랜에서 화면 절반이 통으로 사라지는 것보다 낫다.
    /// 지역이 없는 플랜(직접 만든 것)은 여전히 맞출 자리가 없어 지도를 숨긴다.
    private var regionCamera: RegionMapCamera? {
        current.region?.mapCamera
    }

    private var hasMap: Bool {
        mappedStops.contains { $0.place.latitude != nil && $0.place.longitude != nil }
            || regionCamera != nil
    }

    var body: some View {
        // 제목은 시트 컨테이너 **밖**에 둔다. 시안의 "Day별 view"(519:775)에서 지도가 사라져도
        //  제목과 날짜는 남아 있다 — 즉 시트가 가장 높이 올라가도 제목까지는 덮지 않는다.
        //  제목을 아래 GeometryReader 밖으로 빼면 "시트 최대 = 컨테이너 100%"가 곧 그 동작이 된다.
        VStack(spacing: 0) {
            header
            titleBlock

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    if showsMap {
                        // 지도는 남은 영역을 다 차지한다. 시트가 내려갈수록 지도가 그만큼 넓어진다.
                        //  bottomInset은 기본 자리(55%)에서 시트에 덮이는 높이 — 드래그마다 바꾸면
                        //  카메라가 계속 다시 맞춰져 흔들리므로 고정값으로 둔다.
                        PlanRouteMap(
                            stops: mappedStops,
                            bottomInset: geo.size.height * SheetDetent.medium.fraction,
                            regionCamera: regionCamera,
                            draw: $mapDrawn
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { mapDrawn = true }
                        .onDisappear { mapDrawn = false }
                    }

                    sheet(totalHeight: geo.size.height)
                        .frame(height: sheetHeight(in: geo.size.height))
                }
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .navigationDestination(isPresented: $isEditing) {
            // 편집은 상세를 받은 뒤에만 열린다(`dayHeader` 참고) — 목록의 빈 일정으로 저장하면
            // 서버의 일정이 통째로 지워지기 때문이다.
            // 여행 기간 전체를 넘긴다 — 아직 비어 있는 날로도 항목을 옮길 수 있어야 한다.
            PlanEditView(days: dayCandidates) { try await save($0) }
        }
        // 일정에 박제된 값만 넘긴다 — 주소는 들고 있지 않아 후기 화면이 스스로 받아 온다.
        .navigationDestination(item: $reviewTarget) { place in
            if let contentID = place.contentID {
                PlaceReviewsView(contentId: contentID, placeName: place.name)
            }
        }
        // 메모는 편집 화면을 거치지 않고 상세에서 바로 붙인다 — 시안의 버튼이 상세 하단에 있고,
        // 한 줄 적으러 편집 모드까지 들어가게 하면 순서까지 건드릴 수 있는 화면이 열린다.
        .sheet(isPresented: $isEditingTitle) {
            PlanTitleEditView(currentTitle: current.title) { try await renameTitle(to: $0) }
        }
        .sheet(isPresented: $isAddingMemo) {
            PlanMemoComposeView(days: dayCandidates) { day, text in
                try await addMemo(to: day, text: text)
            }
        }
        .sheet(isPresented: $isAddingPlace) {
            PlanPlaceAddView(days: dayCandidates, regionCamera: regionCamera) { day, places in
                try await addPlaces(to: day, places: places)
            }
        }
    }

    // MARK: 로드 · 저장

    private func load() async {
        // 저장하고 돌아온 뒤 다시 열렸을 때까지 처음부터 받을 필요는 없다.
        guard detail == nil else { return }
        loadFailed = false
        do {
            detail = try await planService.fetchPlan(id: plan.id)
        } catch {
            loadFailed = true
        }
    }

    /// 편집 화면의 "완료". 실패는 그대로 던져 편집 화면이 사유를 띄우고 열린 채로 남게 한다 —
    /// 여기서 삼키면 사용자는 저장된 줄 알고 나가 버린다.
    private func save(_ days: [PlanDay]) async throws {
        // 상세를 못 받은 상태의 플랜으로 저장하면 서버의 일정이 지워진다.
        guard var target = detail else { throw PlanServiceError.unavailable }
        // 편집 화면은 여행 기간의 **모든** 날을 보여 준다(빈 날도 옮길 자리가 되어야 하므로).
        // 그대로 저장하면 아무것도 안 담긴 날이 서버에 생겨 타임라인에 줄줄이 남는다.
        target.days = days.filter { !$0.items.isEmpty }
        let saved = try await planService.savePlan(target, authorNm: nil)
        detail = saved
        onPlanSaved(saved)
    }

    /// 제목만 바꾼다. **`detail` 로만 저장한다** — 목록에서 온 플랜(`days` 가 빈 배열)으로 부르면
    /// PUT 이 본문을 통째로 갈아 끼우면서 서버의 일정이 지워진다.
    /// 실패는 그대로 던져 시트가 사유를 띄우고 열린 채 남게 한다 — 고쳐 쓴 제목을 잃지 않는다.
    private func renameTitle(to newTitle: String) async throws {
        guard var target = detail else { throw PlanServiceError.unavailable }
        target.title = newTitle
        let saved = try await planService.savePlan(target, authorNm: nil)
        detail = saved
        onPlanSaved(saved)
    }

    /// 무언가를 담을 후보 날짜 — **여행 기간 전체**다.
    ///
    /// 서버에 있는 날만 후보로 두면 안 된다: 새 플랜은 `days`가 비어 있고(`PlanDraft`),
    /// 한 번 담고 난 뒤에는 담긴 날 하나만 남아 둘째 날부터 영영 고를 수 없다.
    /// `Plan.dayCandidates`가 기간 전체와 이미 있는 날을 겹쳐 준다.
    private var dayCandidates: [PlanDay] {
        // 상세를 받기 전(`detail == nil`)에는 목록에서 온 플랜에 일정이 없다 — 그때는
        // 하단 액션 자체가 그려지지 않으므로 여기까지 오지 않는다.
        current.dayCandidates()
    }

    /// 고른 Day의 **맨 뒤**에 메모를 붙인다.
    ///
    /// 그날 어디쯤에 끼울지는 묻지 않는다 — 시안에 위치를 고르는 UI가 없고, 붙인 뒤
    /// 편집 화면에서 드래그로 옮길 수 있다(같은 Day 안에서는 자유롭게 움직인다).
    /// 저장 실패는 그대로 던져 시트가 사유를 띄우고 열린 채 남게 한다 — 여기서 삼키면
    /// 사용자는 메모가 들어간 줄 알고 시트를 닫는다.
    private func addMemo(to day: PlanDay, text: String) async throws {
        try await append(.memo(PlanMemo(text: text)), to: day)
    }

    /// 고른 장소들을 **고른 순서 그대로** 그 날 맨 뒤에 담는다.
    ///
    /// 여러 곳을 한 번에 담아도 저장은 한 번이다 — `savePlan`이 본문을 통째로 교체하므로
    /// 장소마다 부르면 왕복이 늘 뿐 아니라, 중간에 실패했을 때 몇 개까지 들어갔는지가 흐려진다.
    private func addPlaces(to day: PlanDay, places: [PlanPlace]) async throws {
        try await append(contentsOf: places.map { .stop(PlanStop(place: $0)) }, to: day)
    }

    private func append(_ item: PlanDayItem, to day: PlanDay) async throws {
        try await append(contentsOf: [item], to: day)
    }

    /// 담기의 공통 경로 — 메모든 장소든 "그 날 맨 뒤에 붙이고 통째로 저장" 이 같다.
    private func append(contentsOf items: [PlanDayItem], to day: PlanDay) async throws {
        guard var target = detail, !items.isEmpty else { throw PlanServiceError.unavailable }

        if let index = target.days.firstIndex(where: { $0.id == day.id }) {
            target.days[index].items.append(contentsOf: items)
        } else {
            // 아직 서버에 없는 날(`calendarDays`가 만든 후보). 실제로 담길 때 비로소 생긴다 —
            // 미리 빈 날을 만들어 두면 아무것도 안 담은 날이 타임라인에 줄줄이 남는다.
            var created = day
            created.items = items
            target.days.append(created)
            target.days.sort { $0.date < $1.date }
        }

        let saved = try await planService.savePlan(target, authorNm: nil)
        detail = saved
        onPlanSaved(saved)
    }

    // MARK: 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }

            Text("여행 상세")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .padding(.leading, 14)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                // 돋보기는 **장소 추가와 같은 동작**이다(피그마 코멘트, 2026-08-16). 담을 장소를
                //  찾는 일이라 하단 "장소 추가" 버튼과 목적지가 같다 — 헤더에서도 닿게 해 둔 것.
                headerIcon("plan_search", size: 25) { isAddingPlace = true }
                    .accessibilityLabel("장소 추가")
                // 연필은 제목 변경(피그마 코멘트). 장소 상세와 같은 글리프라(좌표만 +2.7 평행이동)
                //  기존 에셋을 그대로 쓴다.
                //  시안은 26 박스 안에 21.4짜리 연필을 담지만 detail_pencil은 여백 없이 뽑혀 있다 —
                //  26으로 그리면 아트워크가 21.5% 커져 획이 두꺼워지므로 원래 크기로 그린다.
                headerIcon("detail_pencil", size: 21.41, slot: 26) { isEditingTitle = true }
                    .accessibilityLabel("제목 변경")
                    // 상세를 못 받았으면 저장할 원본이 없다 — 눌러도 되는 것처럼 보이면 안 된다.
                    .disabled(detail == nil)
                // 지도는 접힌 지도 위에 핀이 얹힌 2색 아이콘이라 틴트를 입히면 핀이 묻힌다.
                //  헤더의 지도 버튼은 "지도를 보고 싶다"는 뜻이므로 한 칸씩 도는 핸들과 달리
                //  지도가 가장 큰 자리로 곧장 간다. 이미 그 자리면 기본 자리로 되돌린다.
                headerIcon("plan_map", size: 26, isTemplate: false) { focusMap() }
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

    /// `slot`은 시안의 아이콘 박스 크기, `size`는 그 안에 실제로 그려지는 아트워크 크기다.
    /// 에셋마다 여백 포함 여부가 달라 둘을 분리해 둔다.
    private func headerIcon(
        _ name: String,
        size: CGFloat,
        slot: CGFloat? = nil,
        isTemplate: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(name)
                .renderingMode(isTemplate ? .template : .original)
                .resizable()
                .frame(width: size, height: size)
                .frame(width: slot ?? size, height: slot ?? size)
        }
    }

    /// 지도를 그릴지. 시트가 화면을 다 덮으면 카카오맵 엔진을 내려 자원을 아낀다 —
    /// 드래그 중에는 판정하지 않는다(끄는 순간 뒤가 비어 보이고, 손을 떼면 다시 켜져 깜빡인다).
    private var showsMap: Bool { hasMap && detent != .listOnly }

    /// 접힌 상태에서도 손잡이는 남긴다. 높이를 정말 0으로 만들면 잡을 것이 사라져
    /// 드래그로 되돌릴 방법이 없어진다(헤더 지도 버튼만 남는다).
    private static let handleHeight: CGFloat = 34

    private func height(for detent: SheetDetent, in total: CGFloat) -> CGFloat {
        max(total * detent.fraction, Self.handleHeight)
    }

    /// 정지점 높이에 드래그 이동량을 얹은 실제 높이. 위로 끌면 커진다(이동량이 음수).
    ///  최소·최대를 넘어서도 조금은 따라오게 두면(고무줄) 끝에 닿았다는 감각이 생긴다.
    private func sheetHeight(in total: CGFloat) -> CGFloat {
        guard hasMap else { return total }
        let base = height(for: detent, in: total)
        return min(max(base - dragOffset, Self.handleHeight), total + 24)
    }

    /// 손을 뗀 위치와 속도로 정지점을 고른다.
    ///  속도를 함께 보는 이유: 짧고 빠르게 튕겼을 때 거리가 모자라도 다음 자리로 넘어가야
    ///  "던졌다"는 조작 의도와 맞는다.
    private func settle(translation: CGFloat, velocity: CGFloat, total: CGFloat) {
        let projected = height(for: detent, in: total) - translation - velocity * 0.12
        let target = SheetDetent.allCases.min {
            abs(height(for: $0, in: total) - projected) < abs(height(for: $1, in: total) - projected)
        } ?? detent

        withAnimation(.snappy(duration: 0.32, extraBounce: 0.05)) {
            detent = target
            dragOffset = 0
        }
    }

    private func focusMap() {
        guard hasMap else { return }
        withAnimation(.snappy(duration: 0.28)) {
            detent = detent == .collapsed ? .medium : .collapsed
        }
    }

    /// 핸들 탭 — 다음 자리로 한 칸씩 돈다. 드래그를 쓸 수 없는 사용자에게 유일한 조작 수단이라
    /// 세 자리를 모두 거쳐야 한다.
    private func advanceDetent() {
        guard hasMap else { return }
        let all = SheetDetent.allCases
        let next = all[(all.firstIndex(of: detent)! + 1) % all.count]
        withAnimation(.snappy(duration: 0.28)) { detent = next }
    }

    // MARK: 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(current.title)
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)

            Text(current.dateRangeText)
                .font(.notoSans(16, .regular, relativeTo: .body))
                .tracking(-0.4)
        }
        .foregroundStyle(Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 25)
    }

    // MARK: 바텀시트

    private func sheet(totalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            handle(totalHeight: totalHeight)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if detail == nil {
                        // 일정이 아직 없다 — 왜 없는지(받는 중 / 실패)를 구분해 알린다.
                        if loadFailed { errorRow } else { loadingRow }
                    } else if days.isEmpty {
                        emptyRow
                    } else {
                        // 날 하나가 통째로 하나의 스크롤 대상이어야 `scrollPosition` 이
                        // "지금 맨 위에 걸린 날"을 짚어 준다 — 그 값으로 지도 핀을 바꾼다.
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                                VStack(alignment: .leading, spacing: 0) {
                                    dayHeader(number: index + 1, day: day)
                                    dayTimeline(day)
                                }
                                .id(day.id)
                            }
                        }
                        .scrollTargetLayout()
                    }

                    // 상세를 못 받은 상태에서는 일정을 더할 곳이 없다 — 실패 문구 아래 액션만 남으면
                    // 눌러도 되는 것처럼 읽힌다.
                    if detail != nil { bottomActions }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
            }
            // 맨 위에 걸린 날을 짚어 준다. 스크롤 도중 nil 이 오기도 해서 읽는 쪽이 폴백한다.
            .scrollPosition(id: $visibleDayID, anchor: .top)
        }
        .background(Color.appBackground)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: Color.deepGreen.opacity(0.08), radius: 10, y: -2)
    }

    /// 시안(652:3056)의 회색 손잡이 바. 드래그와 탭을 함께 받는다.
    ///
    ///  드래그를 **핸들 영역에만** 붙인 이유: 시트 본문은 ScrollView 이고 뒤에는 카카오맵이 있어,
    ///  넓게 잡으면 셋이 같은 제스처를 두고 다툰다(지도 뷰가 스와이프를 삼키는 문제가 이미 있었다).
    ///  버튼 역할을 유지하는 이유: 드래그는 VoiceOver·스위치 제어로 쓸 수 없는 조작이라
    ///  탭만으로도 세 자리를 모두 돌 수 있어야 한다.
    private func handle(totalHeight: CGFloat) -> some View {
        Button(action: advanceDetent) {
            Capsule()
                .fill(Color.cardStroke)
                .frame(width: 39, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!hasMap)
        .opacity(hasMap ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { dragOffset = $0.translation.height }
                .onEnded {
                    settle(translation: $0.translation.height,
                           velocity: $0.velocity.height,
                           total: totalHeight)
                }
        )
        .accessibilityLabel("일정 시트 크기")
        .accessibilityValue(detent.label)
        .accessibilityHint("두 번 탭하면 다음 크기로 바뀝니다")
    }

    // MARK: Day

    private func dayHeader(number: Int, day: PlanDay) -> some View {
        HStack(spacing: 0) {
            Text("DAY \(number) · \(day.headerText)")
                .font(.notoSans(16, .bold, relativeTo: .headline))

            Spacer(minLength: 0)

            Button { isEditing = true } label: {
                Text("편집")
                    .font(.notoSans(16, .medium, relativeTo: .headline))
            }
            .accessibilityHint("일정 순서를 바꿉니다")
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: 로딩 · 오류 · 빈 상태

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.deepGreen)
            Text("일정을 불러오는 중이에요")
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        // 스피너는 스크린리더에 아무것도 전달하지 않는다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("일정을 불러오는 중이에요")
    }

    private var errorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("일정을 불러오지 못했어요")
                .font(.notoSans(15, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)

            Text("네트워크 상태를 확인하고 다시 시도해 주세요")
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await load() }
            } label: {
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
            .accessibilityLabel("일정 다시 불러오기")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("아직 일정이 없어요")
                .font(.notoSans(15, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .foregroundStyle(Color.textPrimary)

            Text("가고 싶은 장소와 메모를 날짜별로 담아 보세요")
                .font(.notoSans(13, .regular, relativeTo: .footnote))
                .tracking(-0.4)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
    }

    /// 번호 뱃지 뒤로 점선이 세로로 지난다(시안 Line 3). 뱃지 중심에 맞춰 깔아둔다.
    private func dayTimeline(_ day: PlanDay) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                switch item {
                case .stop(let stop):
                    // 앞 정류지에서 여기까지의 직선 거리. 좌표가 없으면 구간을 그리지 않는다.
                    if let previous = day.stopBefore(index),
                       let leg = TravelLeg.straightLine(from: previous.place, to: stop.place) {
                        PlanLegRow(leg: leg)
                    }
                    PlanStopRow(number: day.stopNumber(at: index) ?? 0, stop: stop) {
                        reviewTarget = stop.place
                    }
                case .memo(let memo):
                    PlanMemoRow(memo: memo)
                }
            }
        }
        .background(alignment: .topLeading) {
            DashedVerticalLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.cardStroke)
                .frame(width: 1)
                .padding(.leading, 11.5)
        }
        .padding(.bottom, 16)
    }

    // MARK: 하단 액션

    private var bottomActions: some View {
        HStack(spacing: 11) {
            bottomButton("장소 추가") { isAddingPlace = true }
            bottomButton("메모 추가") { isAddingMemo = true }
        }
        .padding(.top, 14)
    }

    private func bottomButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.notoSans(16, .medium, relativeTo: .headline))
                .tracking(-0.064)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.cardStroke, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 장소 행

private struct PlanStopRow: View {
    let number: Int
    let stop: PlanStop
    /// 별을 눌렀을 때. 이 행은 네비게이션 밖에 있어 이동은 상세 화면이 맡는다.
    var onReviewTap: () -> Void

    private var place: PlanPlace { stop.place }

    var body: some View {
        HStack(spacing: 14) {
            PlanNumberBadge(number: number, isCustom: place.isCustom)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.notoSans(16, .medium, relativeTo: .headline))
                        .tracking(-0.064)
                        .foregroundStyle(Color.textPrimary)

                    Text(place.subtitle)
                        .font(.notoSans(14, .regular, relativeTo: .subheadline))
                        .tracking(-0.056)
                        .foregroundStyle(Color.textSecondary)
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                if place.showsReviewAction {
                    Rectangle()
                        .fill(Color.cardStroke)
                        .frame(width: 1, height: 56)

                    // 장소 후기 화면으로 간다(2026-08-16). `showsReviewAction` 이 이미
                    //  `contentID != nil` 일 때만 이 버튼을 그리므로 여기서 다시 확인하지 않는다 —
                    //  나만의 장소는 관광공사 원본이 없어 후기를 붙일 대상이 없다.
                    Button(action: onReviewTap) {
                        VStack(spacing: 3) {
                            Image("star")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 15, height: 14.27)
                            Text("리뷰")
                                .font(.notoSans(11, .regular, relativeTo: .caption))
                                .tracking(-0.044)
                        }
                        .foregroundStyle(Color.deepGreen)
                        .frame(width: 61)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(place.name) 후기 보기")
                }
            }
            .padding(.leading, 16)
            .frame(height: 57)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardStroke, lineWidth: 1)
            }
        }
    }
}

// MARK: - 이동 거리

private struct PlanLegRow: View {
    let leg: TravelLeg

    var body: some View {
        Text(leg.distanceText)
            .font(.notoSans(12, .medium, relativeTo: .caption))
            .foregroundStyle(Color.iconGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 39)
    }
}

// MARK: - 메모

/// 시안에 메모 렌더가 없어 장소 카드 규격(라운드·좌측 정렬)만 따라간 임시 형태다.
private struct PlanMemoRow: View {
    let memo: PlanMemo

    var body: some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: 24, height: 24)

            Text(memo.text)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.056)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.photoPlaceholder, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 점선

private struct DashedVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// 목록에서 넘어오는 상황과 같게 `days`를 비워 넘긴다 — 상세는 서비스에서 다시 받는다.
private var listEntry: Plan {
    var summary = MockData.upcomingGyeongju
    summary.days = []
    return summary
}

#Preview("목 데이터") {
    NavigationStack {
        PlanDetailView(plan: listEntry)
            .environment(\.planService, MockPlanService())
    }
}

#Preview("상세 실패") {
    NavigationStack {
        PlanDetailView(plan: listEntry)
            .environment(\.planService, FailingPlanService())
    }
}
