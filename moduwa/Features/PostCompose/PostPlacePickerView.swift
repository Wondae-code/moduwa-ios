import SwiftUI

/// 게시글에 붙일 장소 고르기 — 게시글 작성 툴바의 지도 버튼.
///
/// 검색 화면(`SearchView`)·플랜 담기(`PlanPlaceAddView`)와 **같은 부품**을 쓴다
/// (`PlaceSearchUI`) — 세 화면에서 장소를 찾는 모습이 달라질 이유가 없다.
///
/// 다른 것은 고른 뒤의 동작뿐이다. 여기서는 하나를 고르면 곧바로 닫힌다 —
/// 플랜 담기처럼 여러 개를 모아 담는 화면이 아니라, 글에 방금 언급한 곳을 붙이는 자리다.
struct PostPlacePickerView: View {
    /// 이미 붙인 장소들. 목록에서 표시만 하고 다시 고르지 못하게 한다.
    let attached: [Place]
    var onPick: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeSearchService) private var placeSearchService

    @State private var query = ""
    @State private var searchRequest: SearchRequest?
    /// 검색 화면과 같은 것을 쓴다 — 상태·누적 결과·오프셋을 함께 들고 있다.
    @State private var search = PlaceSearchPaginator()
    @FocusState private var isFieldFocused: Bool
    /// 검색 화면과 **같은 최근 검색어**를 본다.
    @AppStorage(RecentSearchStore.key) private var recentSearchesData = Data()

    private var recentSearches: [String] { RecentSearchStore.decode(recentSearchesData) }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            content
        }
        .background(.white)
        .presentationDragIndicator(.visible)
        .task(id: searchRequest) { await loadSearchResults() }
        .onAppear { isFieldFocused = true }
    }

    /// `SearchView.headerBar` 와 같은 배치 — 왼쪽만 시트를 닫는 X 다.
    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .foregroundStyle(.textPrimary)
            .accessibilityLabel("닫기")

            PlaceSearchField(query: $query, focus: $isFieldFocused) {
                submit(query)
            } onClear: {
                query = ""
                searchRequest = nil
                search.reset()
                isFieldFocused = true
            }
            .onChange(of: query) {
                if query != searchRequest?.term {
                    searchRequest = nil
                    search.reset()
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

    @ViewBuilder
    private var content: some View {
        switch search.phase {
        case .idle:
            idleContent
        case .loading:
            PlaceSearchLoading()
        case .empty:
            PlaceSearchMessage(title: "검색 결과가 없어요",
                               subtitle: "다른 장소 이름이나 지역으로 검색해 보세요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            VStack(spacing: 14) {
                PlaceSearchMessage(title: "검색 결과를 불러오지 못했어요",
                                   subtitle: "네트워크를 확인한 뒤 다시 시도해 주세요")
                Button("다시 시도") {
                    guard let term = searchRequest?.term else { return }
                    searchRequest = SearchRequest(term: term)
                }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results:
            PlaceSearchResultList(paginator: search) {
                Task { await search.loadMore(using: placeSearchService) }
            } row: { place in
                resultRow(place)
            }
        }
    }

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

                Text("글에 붙일 장소를 검색해 보세요")
                    .font(.notoSans(14))
                    .foregroundStyle(.iconGray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, recentSearches.isEmpty ? 180 : 100)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
        }
    }

    /// 이미 붙인 장소는 고르지 못하게 한다 — 같은 곳을 두 번 붙일 이유가 없고,
    /// 눌러도 아무 일이 없으면 고장으로 읽히므로 체크로 이미 붙었음을 보인다.
    private func resultRow(_ place: Place) -> some View {
        let isAttached = attached.contains { $0.id == place.id }
        let row = PlaceSearchRow(place: place) {
            Image(systemName: isAttached ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 22))
                .foregroundStyle(isAttached ? Color.deepGreen : Color.iconGray)
                .frame(width: 22, height: 22)
        }

        return Button {
            onPick(place)
            dismiss()
        } label: { row }
            .buttonStyle(.plain)
            .disabled(isAttached)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.accessibilityText)
            .accessibilityHint(isAttached ? "이미 붙인 장소예요" : "두 번 탭하면 글에 붙입니다")
    }

    // MARK: - 검색

    private func submit(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecentSearches(RecentSearchStore.adding(trimmed, to: recentSearches))
        searchRequest = SearchRequest(term: trimmed)
        isFieldFocused = false
    }

    private func saveRecentSearches(_ items: [String]) {
        recentSearchesData = RecentSearchStore.encode(items)
    }

    private func loadSearchResults() async {
        guard let request = searchRequest else { return }
        await search.search(request.term, using: placeSearchService)
    }

    /// 같은 검색어를 다시 눌러도 새 요청이 되도록 id 를 섞는다(`SearchView` 와 같은 방식).
    private struct SearchRequest: Hashable {
        let term: String
        private let id = UUID()
    }
}

#Preview("장소 고르기") {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PostPlacePickerView(attached: []) { _ in }
        }
}
