import SwiftUI

/// 검색 화면 (Figma "모두와 UI — 서브 > 검색").
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeSearchService) private var placeSearchService
    @FocusState private var isFieldFocused: Bool
    @State private var query = ""
    @State private var searchRequest: SearchRequest?
    @State private var searchState: SearchState = .idle
    /// 최근 검색어 — 기기 로컬 저장 (최대 10개, 최신순).
    /// 플랜의 "장소 추가"와 **같은 목록을 본다**(`RecentSearchStore`).
    @AppStorage(RecentSearchStore.key) private var recentSearchesData = Data()

    private var recentSearches: [String] {
        RecentSearchStore.decode(recentSearchesData)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            content
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isFieldFocused = true }
        .task(id: searchRequest) { await loadSearchResults() }
    }

    // MARK: - 헤더 (뒤로가기 + 검색 입력 필드)

    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .foregroundStyle(.textPrimary)
            .accessibilityLabel("뒤로")

            PlaceSearchField(query: $query, focus: $isFieldFocused) {
                submit(query)
            } onClear: {
                query = ""
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

    // MARK: - 기본 상태 (최근 검색어)

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

                Text("장소 이름이나 지역으로 검색할 수 있어요")
                    .font(.notoSans(14))
                    .foregroundStyle(.iconGray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, recentSearches.isEmpty ? 200 : 120)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
        }
    }

    // MARK: - 검색 결과

    @ViewBuilder
    private var content: some View {
        switch searchState {
        case .idle:
            idleContent
        case .loading:
            loadingState
        case let .results(page):
            resultsState(page)
        case .empty:
            emptyState
        case .failed:
            failedState
        }
    }

    private var loadingState: some View { PlaceSearchLoading() }

    private func resultsState(_ page: PlaceSearchPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("검색 결과 \(page.total)")
                    .font(.meta13)
                    .foregroundStyle(.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                LazyVStack(spacing: 0) {
                    ForEach(Array(page.items.enumerated()), id: \.element.id) { index, place in
                        NavigationLink(value: place) {
                            PlaceSearchRow(place: place) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.iconGray)
                                    .frame(width: 20, height: 20)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("장소 상세 보기")
                        }
                        .buttonStyle(.plain)

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

    private var emptyState: some View {
        searchMessageState(
            title: "검색 결과가 없어요",
            subtitle: "다른 장소 이름이나 지역으로 검색해 보세요"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            searchMessageState(
                title: "검색 결과를 불러오지 못했어요",
                subtitle: "네트워크를 확인한 뒤 다시 시도해 주세요"
            )
            Button("다시 시도") { retrySearch() }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func searchMessageState(title: String, subtitle: String) -> some View {
        PlaceSearchMessage(title: title, subtitle: subtitle)
    }

    // MARK: - 동작

    private func submit(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecentSearches(RecentSearchStore.adding(trimmed, to: recentSearches))
        searchState = .loading
        searchRequest = SearchRequest(term: trimmed)
        isFieldFocused = false
    }

    private func retrySearch() {
        guard let term = searchRequest?.term else { return }
        searchState = .loading
        searchRequest = SearchRequest(term: term)
    }

    private func loadSearchResults() async {
        guard let request = searchRequest else { return }

        do {
            let page = try await placeSearchService.searchPlaces(query: request.term, limit: 20, offset: 0)
            guard !Task.isCancelled, searchRequest == request else { return }
            searchState = page.items.isEmpty ? .empty : .results(page)
        } catch is CancellationError {
            // 새 검색어가 입력되면 이전 요청은 자동으로 취소된다.
        } catch {
            guard !Task.isCancelled, searchRequest == request else { return }
            searchState = .failed
        }
    }

    private func saveRecentSearches(_ items: [String]) {
        recentSearchesData = RecentSearchStore.encode(items)
    }

    private struct SearchRequest: Hashable {
        let term: String
        private let id = UUID()
    }

    private enum SearchState {
        case idle
        case loading
        case results(PlaceSearchPage)
        case empty
        case failed
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
