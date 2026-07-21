import SwiftUI

/// 검색 화면 (Figma "모두와 UI — 서브 > 검색").
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.placeSearchService) private var placeSearchService
    @FocusState private var isFieldFocused: Bool
    @State private var query = ""
    @State private var searchRequest: SearchRequest?
    @State private var searchState: SearchState = .idle
    /// 최근 검색어 — 기기 로컬 저장 (최대 10개, 최신순)
    @AppStorage("recentSearches") private var recentSearchesData = Data()

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
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

            HStack(spacing: 8) {
                Image("search")
                    .renderingMode(.template)
                    .foregroundStyle(.textSecondary)
                TextField("장소, 지역으로 검색", text: $query)
                    .font(.pretendard(15))
                    .foregroundStyle(.textPrimary)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .onSubmit { submit(query) }
                    .onChange(of: query) {
                        if query != searchRequest?.term {
                            searchRequest = nil
                            searchState = .idle
                        }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.iconGray)
                    }
                    .accessibilityLabel("입력 지우기")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Capsule().fill(Color.photoPlaceholder))
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
                            .font(.pretendard(16, .bold))
                            .foregroundStyle(.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("전체 삭제") { saveRecentSearches([]) }
                            .font(.pretendard(13))
                            .foregroundStyle(.textSecondary)
                    }

                    FlowChips(items: recentSearches) { term in
                        query = term
                        submit(term)
                    } onDelete: { term in
                        saveRecentSearches(recentSearches.filter { $0 != term })
                    }
                }

                Text("장소 이름이나 지역으로 검색할 수 있어요")
                    .font(.pretendard(14))
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

    private var loadingState: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .tint(.deepGreen)
            Text("검색 결과를 불러오는 중이에요")
                .font(.pretendard(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

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
                            SearchResultRow(place: place)
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
                .font(.pretendard(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func searchMessageState(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.photoPlaceholder)
                .frame(width: 96, height: 96)
                .overlay {
                    Image("search")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.iconGray)
                }
            Text(title)
                .font(.pretendard(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Text(subtitle)
                .font(.pretendard(14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 동작

    private func submit(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var next = recentSearches.filter { $0 != trimmed }
        next.insert(trimmed, at: 0)
        saveRecentSearches(Array(next.prefix(10)))
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
        recentSearchesData = (try? JSONEncoder().encode(items)) ?? Data()
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

/// Figma "검색 — 결과"의 56pt 썸네일 목록 행.
private struct SearchResultRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: Spacing.m) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(place.name)
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    accessibilityBadge
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(place.region) · \(place.categoryLabel ?? place.category.rawValue)")
                    .font(.meta13)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.iconGray)
                .frame(width: 20, height: 20)
        }
        .padding(.vertical, Spacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.name), \(place.region), \(place.categoryLabel ?? place.category.rawValue), \(place.feature.label)")
        .accessibilityHint("장소 상세 보기")
    }

    private var thumbnail: some View {
        Color.photoPlaceholder
            .frame(width: 56, height: 56)
            .overlay {
                if let imageURL = place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private var accessibilityBadge: some View {
        Circle()
            .fill(Color.deepGreen)
            .frame(width: 20, height: 20)
            .overlay {
                Image("access_wheelchair")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// 최근 검색어 칩 — 삭제 버튼 포함, 줄바꿈 플로우 레이아웃
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void
    let onDelete: (String) -> Void

    init(items: [String], onTap: @escaping (String) -> Void, onDelete: @escaping (String) -> Void) {
        self.items = items
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { term in
                HStack(spacing: 6) {
                    Button { onTap(term) } label: {
                        Text(term)
                            .font(.pretendard(14))
                            .foregroundStyle(.textSecondary)
                    }
                    Button { onDelete(term) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.iconGray)
                    }
                    .accessibilityLabel("\(term) 삭제")
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            }
        }
    }
}

/// 간단한 좌→우 줄바꿈 레이아웃
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
