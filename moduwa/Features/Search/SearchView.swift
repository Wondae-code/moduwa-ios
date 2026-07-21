import SwiftUI

/// 검색 화면 (Figma "모두와 UI — 서브 > 검색").
/// 검색 API(moduwa-backend#3) 확정 전이라 입력·최근 검색어 관리까지만 동작하고,
/// 검색 실행 시엔 준비 중 안내를 보여준다.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    @State private var query = ""
    @State private var submittedQuery: String?
    /// 최근 검색어 — 기기 로컬 저장 (최대 10개, 최신순)
    @AppStorage("recentSearches") private var recentSearchesData = Data()

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if let submitted = submittedQuery {
                preparingState(for: submitted)
            } else {
                idleContent
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isFieldFocused = true }
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
                        if query.isEmpty { submittedQuery = nil }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        submittedQuery = nil
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

    // MARK: - 검색 실행 후 (API 준비 중)

    private func preparingState(for term: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
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
            Text("‘\(term)’ 검색 결과를 준비 중이에요")
                .font(.pretendard(18, .bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 4)
            Text("장소 검색 기능이 곧 열릴 예정이에요")
                .font(.pretendard(14))
                .foregroundStyle(.textSecondary)
            Spacer()
            Spacer()
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
        submittedQuery = trimmed
        isFieldFocused = false
    }

    private func saveRecentSearches(_ items: [String]) {
        recentSearchesData = (try? JSONEncoder().encode(items)) ?? Data()
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
