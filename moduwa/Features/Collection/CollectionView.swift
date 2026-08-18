import SwiftUI

/// 저장 탭 — Figma "04. 저장 - 모아보기"(642:837) / "좋아요한 게시물"(642:1255)
///
/// 저장한 장소를 **카테고리별로 묶어** 보여 준다. 칩으로 한 종류만 보거나 전체를 볼 수 있다.
///
/// "좋아요한 게시물"은 아직 담을 것이 없다 — 앱 어디에도 좋아요 버튼이 없고
/// (`ReviewCard`는 숫자만 그린다) 서버에도 누가 무엇을 좋아했는지 담는 자리가 없다.
/// 그 탭은 좋아요 기능을 먼저 깐 뒤에 채운다.
struct CollectionView: View {
    @Environment(SavedPlacesStore.self) private var store

    @State private var selectedTab: SavedTab = .places
    @State private var selectedCategory: PlaceCategory?

    /// 시안 세그먼트 그대로.
    enum SavedTab: String, CaseIterable, Hashable {
        case places = "저장 모아보기"
        case liked = "좋아요한 게시물"
    }

    /// 칩 순서는 시안(전체 / 숙소 / 맛집 / 관광지)을 따른다.
    /// 축제·공연·전시는 시안 칩에 없지만 저장은 될 수 있어, "전체"에서는 함께 보인다.
    private static let chipCategories: [PlaceCategory] = [.stay, .food, .attraction]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                UnderlineTabBar(tabs: SavedTab.allCases, selection: $selectedTab)

                switch selectedTab {
                case .places:
                    categoryChips
                    placeList
                case .liked:
                    ComingSoonView(
                        title: "좋아요한 게시물",
                        systemImage: "heart",
                        message: "좋아요한 게시물 모아보기는 준비 중이에요"
                    )
                }
            }
            .background(Color.appBackground)
            // 홈과 같은 자리에 같은 버튼. 하단에 고정 바가 없어 겹칠 것이 없다.
            .overlay(alignment: .bottomTrailing) { WriteFloatingButton() }
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
        }
        // 다른 화면에서 저장을 눌렀을 수도 있다 — 탭을 열 때마다 최신을 받는다.
        .task { await store.load() }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Text("내 저장")
                .font(.notoSans(24, .bold, relativeTo: .title2))
                .tracking(-0.4)

            Spacer(minLength: 0)

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
    }

    // MARK: - 카테고리 칩

    /// 서버에 다시 묻지 않고 앱에서 거른다 — 저장 목록은 개인이 고른 것이라 크지 않고,
    /// 칩을 누를 때마다 왕복이 생기면 즉시 반응하지 않는다.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "전체", category: nil)
                ForEach(Self.chipCategories) { chip(label: $0.rawValue, category: $0) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(Color.appBackground)
    }

    private func chip(label: String, category: PlaceCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withoutAnimation { selectedCategory = category }
        } label: {
            HStack(spacing: 6) {
                if let category {
                    Image(category.iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                }
                Text(label)
                    .font(.notoSans(14, isSelected ? .bold : .medium, relativeTo: .subheadline))
                    .tracking(-0.4)
            }
            // 선택을 색만으로 전달하지 않는다 — 글자 굵기와 테두리 유무가 함께 바뀐다.
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(Capsule().fill(isSelected ? Color.deepGreen : .white))
            .overlay(Capsule().stroke(isSelected ? .clear : Color.cardStroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 목록

    /// 시안은 카테고리마다 "저장된 OO 모아보기" 제목을 달고 2열 그리드를 깐다.
    /// 칩으로 한 종류만 골랐어도 제목은 남긴다 — 지금 무엇을 보고 있는지가 사라지면 안 된다.
    @ViewBuilder
    private var placeList: some View {
        let sections = visibleSections
        ScrollView {
            if store.isLoading && !store.didLoad {
                message("저장한 장소를 불러오는 중이에요", isLoading: true)
            } else if store.loadFailed && !store.didLoad {
                failedRow
            } else if sections.isEmpty {
                message(emptyText, isLoading: false)
            } else {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sections, id: \.category) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            Text("저장된 \(section.category.rawValue) 모아보기")
                                .font(.notoSans(18, .bold, relativeTo: .title3))
                                .tracking(-0.4)
                                .foregroundStyle(Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)

                            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 14) {
                                ForEach(section.places) { place in
                                    NavigationLink(value: place) {
                                        SavedPlaceCard(place: place)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBackground)
        .refreshable { await store.load() }
    }

    private static let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
    ]

    /// 저장 순서를 지키면서 카테고리별로 묶는다 — 먼저 저장한 종류의 섹션이 위로 온다.
    private var visibleSections: [(category: PlaceCategory, places: [Place])] {
        let filtered = selectedCategory.map { c in store.places.filter { $0.category == c } }
            ?? store.places
        var order: [PlaceCategory] = []
        var grouped: [PlaceCategory: [Place]] = [:]
        for place in filtered {
            if grouped[place.category] == nil { order.append(place.category) }
            grouped[place.category, default: []].append(place)
        }
        return order.map { (category: $0, places: grouped[$0] ?? []) }
    }

    private var emptyText: String {
        selectedCategory == nil
            ? "저장한 장소가 없어요"
            : "저장한 \(selectedCategory?.rawValue ?? "")이(가) 없어요"
    }

    private func message(_ text: String, isLoading: Bool) -> some View {
        VStack(spacing: 10) {
            if isLoading { ProgressView().tint(.deepGreen) }
            Text(text)
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
            if !isLoading {
                Text("장소 상세에서 저장하기를 눌러 담아 보세요")
                    .font(.notoSans(13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .combine)
    }

    private var failedRow: some View {
        VStack(spacing: 14) {
            Text("저장한 장소를 불러오지 못했어요")
                .font(.notoSans(15, .bold))
                .foregroundStyle(Color.textPrimary)
            Button("다시 시도") { Task { await store.load() } }
                .font(.notoSans(14, .bold))
                .foregroundStyle(.deepGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(.deepGreen, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    CollectionView()
        .environment(SavedPlacesStore(service: MockFeedService()))
}
