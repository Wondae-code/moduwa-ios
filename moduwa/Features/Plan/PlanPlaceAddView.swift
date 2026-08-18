import SwiftUI

/// 일정에 장소 담기 — 플랜 상세 하단 "장소 추가"(시안 519:808 / 519:89).
///
/// **모두와 자체 시안 없음**(2026-08-16 피그마 전수 확인). 상세 시안에는 회색 알약 버튼 자리만 있고,
/// 유일한 지시가 `519:1178` "예시 - 나만의 장소 추가 화면 (트리플 스샷)" 의 1단계(장소 검색)다.
/// 나머지는 검색 화면(`SearchView`)과 후기 작성 화면의 톤을 따랐다.
///
/// **한 번에 여러 곳을 담는다**(2026-08-16 사용자 결정). 하루치 일정을 짤 때는 보통 여러 곳을
/// 연달아 담게 되는데, 하나씩이면 그때마다 검색을 다시 해야 한다. 저장도 `savePlan` 한 번으로 끝난다.
///
/// **어느 날에 담을지는 묻지 않는다**(2026-08-16 사용자 지시) — 상세에서 보고 있던 날에 그대로
/// 들어간다. 다른 날에 담으려면 상세에서 그 날로 넘어간 뒤 다시 연다.
struct PlanPlaceAddView: View {
    /// 장소가 들어갈 날. 서버에 이미 있는 날일 수도, 여행 기간에서 만들어 낸 후보일 수도 있다.
    let day: PlanDay
    /// 여행 기간에서 이 날이 몇 번째인지("DAY 2"). 날짜만으로는 알 수 없어 상세가 넘겨 준다.
    let dayNumber: Int
    /// 나만의 장소를 만들 때 지도를 처음 띄울 자리 — 플랜의 여행 지역.
    /// 지역이 없는 플랜이면 nil 이고, 그때는 "나만의 장소 추가"를 열지 않는다(띄울 자리가 없다).
    var regionCamera: RegionMapCamera?
    /// 고른 장소들을 그 날에 담는다.
    ///
    /// **저장이 끝날 때까지 기다린다** — 시트를 먼저 닫고 뒤에서 저장하면 실패했을 때
    /// 방금 고른 목록이 어디에도 남지 않는다(`PlanMemoComposeView` 와 같은 규칙).
    var onAdd: ([PlanPlace]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeSearchService) private var placeSearchService

    @State private var query = ""
    @State private var searchRequest: SearchRequest?
    @State private var searchState: SearchState = .idle
    /// 고른 장소를 **순서대로** 들고 있다 — 담기는 순간 이 순서로 일정에 들어가므로
    /// `Set` 으로 두면 사용자가 고른 차례가 사라진다.
    @State private var picked: [Place] = []
    /// 직접 만든 장소들. 검색 결과에 없으므로 목록에서 체크로 표현할 수 없어 따로 들고 있다가
    /// 결과 위에 별도 구획으로 보여 준다.
    ///
    /// `PlanPlace`가 아니라 `PlanStop`으로 담는 이유는 **id 때문**이다 — 같은 이름·좌표로 두 개를
    /// 만들 수 있어서 값만으로는 어느 줄을 빼는지 가릴 수 없다(`ForEach`도 흔들린다).
    @State private var customPlaces: [PlanStop] = []
    @State private var isAddingCustomPlace = false
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFieldFocused: Bool
    /// 검색 화면과 **같은 목록**을 본다 — 홈에서 찾은 것과 일정에 담으려고 찾은 것은
    /// 사용자에겐 같은 "최근에 찾은 장소"다.
    @AppStorage(RecentSearchStore.key) private var recentSearchesData = Data()

    private var recentSearches: [String] { RecentSearchStore.decode(recentSearchesData) }

    /// 담을 것의 총 개수 — 검색으로 고른 것 + 직접 만든 것.
    private var totalPicked: Int { picked.count + customPlaces.count }

    private var canSubmit: Bool { totalPicked > 0 }

    /// 비활성 상태를 회색이라는 색만으로 전달하지 않기 위한 문장.
    private var missingHint: String? {
        totalPicked == 0 ? "담을 장소를 골라 주세요" : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            targetDayRow

            if !customPlaces.isEmpty { customSection }

            // 검색 결과가 세로를 가장 많이 쓴다 — 여기만 늘어나고 CTA 는 자리를 지킨다.
            resultArea
                .frame(maxHeight: .infinity)
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) { submitBar }
        // 나만의 장소는 **시트 안에 밀어 넣지 않고 전체 화면으로 덮는다.**
        //
        //  그 화면은 대부분이 지도인데, 시트 안에 두면 지도를 끄는 동작을 시트의 끌어 닫기 제스처가
        //  가로챈다. `interactiveDismissDisabled` 로는 부족하다 — **닫히는 것만 막을 뿐 제스처
        //  인식기는 살아 있어서**, 시트가 손가락을 따라 움찔했다 돌아오며 팬을 계속 빼앗는다.
        //  좌우도 마찬가지로 가장자리 스와이프 뒤로가기와 다툰다.
        //  전체 화면 덮기에는 끌어 닫기도 스와이프 뒤로가기도 없어 다툴 상대가 사라진다.
        .fullScreenCover(isPresented: $isAddingCustomPlace) {
            if let regionCamera {
                NavigationStack {
                    PlanCustomPlaceView(initialCamera: regionCamera) { place in
                        withoutAnimation { customPlaces.append(PlanStop(place: place)) }
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task(id: searchRequest) { await loadSearchResults() }
        .onAppear { isFieldFocused = true }
    }

    // MARK: - 헤더 (검색 화면과 같은 줄)

    /// `SearchView.headerBar` 와 같은 배치다 — 다른 것은 왼쪽 버튼뿐이다.
    /// 저기는 뒤로 가는 chevron 이고 여기는 시트를 닫는 X 다.
    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .foregroundStyle(.textPrimary)
            .disabled(isSaving)
            .accessibilityLabel("닫기")

            PlaceSearchField(query: $query, focus: $isFieldFocused) {
                submit(query)
            } onClear: {
                query = ""
                searchRequest = nil
                searchState = .idle
                isFieldFocused = true
            }
            .onChange(of: query) {
                if query != searchRequest?.term {
                    searchRequest = nil
                    searchState = .idle
                }
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 결과

    @ViewBuilder
    private var resultArea: some View {
        switch searchState {
        case .idle:
            idleContent
        case .loading:
            PlaceSearchLoading()
        case .empty:
            // 트리플 1단계 그대로 — 결과가 없을 때 직접 만드는 길을 낸다.
            VStack(spacing: 14) {
                PlaceSearchMessage(title: "검색 결과가 없어요",
                                   subtitle: "찾는 장소가 없다면 직접 등록해 보세요")
                customPlaceButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            VStack(spacing: 14) {
                PlaceSearchMessage(title: "검색 결과를 불러오지 못했어요",
                                   subtitle: "네트워크를 확인한 뒤 다시 시도해 주세요")
                Button("다시 시도") {
                    guard let term = searchRequest?.term else { return }
                    searchState = .loading
                    searchRequest = SearchRequest(term: term)
                }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results(let page):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("검색 결과 \(page.total)")
                        .font(.meta13)
                        .foregroundStyle(.textSecondary)
                        .accessibilityAddTraits(.isHeader)

                    LazyVStack(spacing: 0) {
                        ForEach(Array(page.items.enumerated()), id: \.element.id) { index, place in
                            resultRow(place)

                            // 검색 화면과 같게 마지막 행 뒤에는 선을 긋지 않는다.
                            if index < page.items.count - 1 {
                                Rectangle()
                                    .fill(Color.photoPlaceholder)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    /// 검색 화면과 같은 기본 상태 — 최근 검색어와 안내문.
    /// 최근 검색어는 두 화면이 **같은 목록을 본다**(`RecentSearchStore`).
    private var idleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if !recentSearches.isEmpty {
                    HStack {
                        Text("최근 검색어")
                            .font(.notoSans(16, .bold))
                            .foregroundStyle(.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("전체 삭제") { saveRecentSearches([]) }
                            .font(.notoSans(13))
                            .foregroundStyle(.textSecondary)
                    }

                    RecentSearchChips(items: recentSearches) { term in
                        query = term
                        submit(term)
                    } onDelete: { term in
                        saveRecentSearches(recentSearches.filter { $0 != term })
                    }
                }

                VStack(spacing: 14) {
                    Text("담고 싶은 장소를 검색해 보세요")
                        .font(.notoSans(14))
                        .foregroundStyle(.iconGray)

                    customPlaceButton
                }
                .frame(maxWidth: .infinity)
                .padding(.top, recentSearches.isEmpty ? 160 : 90)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
        }
    }

    /// 지역이 없는 플랜은 지도를 어디에 띄울지 정할 수 없어 이 길을 열지 않는다.
    /// (직접 만든 플랜에 지역이 비는 경우다 — 새 플랜 플로우로 만들면 항상 있다.)
    @ViewBuilder
    private var customPlaceButton: some View {
        if regionCamera != nil {
            Button { isAddingCustomPlace = true } label: {
                Text("나만의 장소 추가")
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(Color.deepGreen)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(Capsule().stroke(Color.deepGreen, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("지도에서 위치를 골라 직접 장소를 만듭니다")
        }
    }

    // MARK: - 직접 만든 장소

    /// 검색 결과에 없으므로 목록 안에 체크로 둘 수 없다. 결과 위에 별도 구획으로 얹고,
    /// 여기서는 체크 대신 **빼기**만 할 수 있다 — 이미 담기로 한 것들이다.
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("직접 추가한 장소")
                .font(.notoSans(13, .bold))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            ForEach(customPlaces) { stop in
                HStack(spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.place.name)
                            .font(.cardTitle)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text(stop.place.subtitle)
                            .font(.meta13)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withoutAnimation { customPlaces.removeAll { $0.id == stop.id } }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.iconGray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(stop.place.name) 빼기")
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    /// 검색 화면과 **같은 행**(`PlaceSearchRow`)을 쓴다. 다른 것은 오른쪽 끝뿐이다 —
    /// 거기서는 상세로 넘어가는 chevron 이고, 여기서는 고를 수 있는 체크다.
    ///
    /// 같은 장소를 두 번 담는 것은 막지 않는다 — 점심과 저녁에 같은 곳을 갈 수도 있고,
    /// 여기서는 체크 상태가 보이므로 실수로 두 번 담기는 경우와 구분된다.
    private func resultRow(_ place: Place) -> some View {
        let index = picked.firstIndex(of: place)
        let isPicked = index != nil
        let row = PlaceSearchRow(place: place) {
            // 고름을 색만으로 전달하지 않는다 — 빈 동그라미/체크 글리프가 형태로 알린다.
            Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isPicked ? Color.deepGreen : Color.iconGray)
                .frame(width: 22, height: 22)
        }

        return Button {
            withoutAnimation {
                if let index { picked.remove(at: index) } else { picked.append(place) }
            }
        } label: {
            row
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityText)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isPicked ? "두 번 탭하면 선택을 해제합니다" : "두 번 탭하면 담을 목록에 넣습니다")
    }

    // MARK: - 담길 날

    /// 어느 날에 담기는지 되짚는 줄. 고르는 자리가 아니라 **알리는 자리**다 —
    /// 검색 결과가 세로를 다투는 화면이라 한 줄로 얇게 얹는다.
    private var targetDayRow: some View {
        Text("\(day.title(number: dayNumber))에 담아요")
            .font(.notoSans(14, .medium))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.photoPlaceholder)
    }

    // MARK: - 하단

    private var submitBar: some View {
        VStack(spacing: 8) {
            if let saveError {
                Text(saveError)
                    .font(.notoSans(13))
                    .foregroundStyle(.deepGreen)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let missingHint {
                Text(missingHint)
                    .font(.notoSans(13))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Task { await save() }
            } label: {
                ZStack {
                    Text(totalPicked == 0 ? "담기" : "\(totalPicked)곳 담기")
                        .font(.notoSans(16, .bold))
                        .foregroundStyle(canSubmit ? .textPrimary : .textSecondary)
                        .opacity(isSaving ? 0 : 1)
                    if isSaving { ProgressView().tint(.textPrimary) }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Capsule().fill(canSubmit ? Color.moduwaGreen : Color.photoPlaceholder))
                .shadow(color: Color(hex: 0x9ACA10).opacity(canSubmit ? 0.3 : 0), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSaving)
            .accessibilityLabel(isSaving ? "담는 중" : "\(totalPicked)곳 담기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 검색

    private func submit(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecentSearches(RecentSearchStore.adding(trimmed, to: recentSearches))
        searchState = .loading
        searchRequest = SearchRequest(term: trimmed)
        isFieldFocused = false
    }

    private func saveRecentSearches(_ items: [String]) {
        recentSearchesData = RecentSearchStore.encode(items)
    }

    private func loadSearchResults() async {
        guard let request = searchRequest else { return }
        do {
            let page = try await placeSearchService.searchPlaces(query: request.term, limit: 20, offset: 0)
            guard !Task.isCancelled, searchRequest == request else { return }
            searchState = page.items.isEmpty ? .empty : .results(page)
        } catch is CancellationError {
            // 새 검색어가 들어오면 이전 요청은 자동으로 취소된다.
        } catch {
            guard !Task.isCancelled, searchRequest == request else { return }
            searchState = .failed
        }
    }

    /// `SearchView` 와 같은 방식 — 같은 검색어를 다시 눌러도 새 요청이 되도록 id 를 섞는다.
    private struct SearchRequest: Hashable {
        let term: String
        private let id = UUID()
    }

    private enum SearchState {
        case idle, loading, results(PlaceSearchPage), empty, failed
    }

    // MARK: - 저장

    private func save() async {
        guard totalPicked > 0 else { return }
        isSaving = true
        saveError = nil
        // 검색으로 고른 것 먼저, 직접 만든 것 나중 — 각각은 고른 차례를 지킨다.
        // 그 뒤 순서는 편집 화면에서 드래그로 바꾼다.
        let places = picked.map { PlanPlace(searchResult: $0) } + customPlaces.map(\.place)
        do {
            try await onAdd(places)
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(places.count)곳을 일정에 담았어요")
            dismiss()
        } catch {
            let message = (error as? PlanServiceError)?.errorDescription
                ?? "장소를 담지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            saveError = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        isSaving = false
    }
}

#Preview("장소 담기") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PlanPlaceAddView(day: MockData.upcomingGyeongju.days[0], dayNumber: 1) { _ in }
        }
}
