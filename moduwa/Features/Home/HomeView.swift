import SwiftUI

/// 홈 피드 (Figma "메인화면")
struct HomeView: View {
    @Environment(\.feedService) private var feedService
    @State private var viewModel = HomeViewModel()
    @State private var isSortPickerPresented = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topSection
                recommendationSection
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.xl)

                reviewSection
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.xl)
            }
        }
        .background(.white)
        .task { await viewModel.loadInitial(using: feedService) }
    }

    // MARK: - 헤더

    private var headerBar: some View {
        HStack {
            Image("logo")
                .accessibilityLabel("모두와 홈")

            Spacer()

            // Figma: 아이콘마다 25×25 정렬 박스, 간격 10
            HStack(spacing: 10) {
                Button {} label: {
                    Image("search")
                        .renderingMode(.template)
                        .frame(width: 25, height: 25)
                }
                .accessibilityLabel("검색")

                Button {} label: {
                    // 알림 벨 에셋은 아직 미제공 — SF Symbol 유지 (시안은 Material Symbols 글리프)
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 25, height: 25)
                        .overlay(alignment: .topTrailing) {
                            // 새 알림이 있을 때만 도트 표시
                            if viewModel.hasNewNotifications {
                                Circle()
                                    .fill(.deepGreen)
                                    .stroke(.white, lineWidth: 1)
                                    .frame(width: 7, height: 7)
                                    .offset(x: -1, y: 1)
                            }
                        }
                }
                .accessibilityLabel(viewModel.hasNewNotifications ? "알림, 새 알림 있음" : "알림")

                Button {} label: {
                    Image("hamburger")
                        .renderingMode(.template)
                        .frame(width: 25, height: 25)
                }
                .accessibilityLabel("메뉴")
            }
            .foregroundStyle(.textPrimary)
        }
        // Figma header: 로고 좌측 28, 아이콘 우측 24 (비대칭), 아이콘 간격 10
        .padding(.leading, 28)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
    }

    // MARK: - 상단 (헤더 + 히어로, 배경 공유)

    /// 헤더와 히어로 카드가 하나의 그라데이션 배경을 공유하며 함께 스크롤된다.
    /// Figma: #CAF354 → 흰색 그라디언트 (히어로 카드 하단 부근에서 흰색 도달)
    private var topSection: some View {
        VStack(spacing: 0) {
            headerBar
            if let hero = viewModel.hero {
                HeroCard(recommendation: hero)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xl)
            }
        }
        .background(
            LinearGradient(
                stops: [
                    .init(color: .gradientLime, location: 0),
                    .init(color: .gradientLime, location: 0.3),
                    .init(color: .white, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(alignment: .top) {
            // 상태바 뒤와 오버스크롤(바운스) 영역까지 배경이 이어지도록 위로 연장
            Color.gradientLime
                .frame(height: 1000)
                .offset(y: -1000)
        }
    }

    // MARK: - 추천 장소

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                title: "내 일정에 어울리는 추천 맛집·장소",
                subtitle: "온보딩 정보를 바탕으로 골라봤어요"
            )

            // 칩 스크롤은 섹션 좌우 마진을 뚫고 화면 끝까지 보이게 한다 (음수 패딩 + 내부 인셋)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { category in
                        CategoryChip(category: category, isSelected: category == viewModel.selectedCategory) {
                            Task { await viewModel.selectCategory(category, using: feedService) }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, 6) // 선택 칩 그림자가 잘리지 않도록
            }
            .padding(.horizontal, -Spacing.xl)
            .padding(.vertical, -6)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(viewModel.places) { place in
                    PlaceCard(place: place)
                }
            }

            if viewModel.canLoadMorePlaces {
                Button {
                    Task { await viewModel.loadMorePlaces(using: feedService) }
                } label: {
                    HStack(spacing: 5) {
                        Text("맞춤 추천 더보기")
                            .font(.pretendard(15, .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.deepGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 여행자 리뷰

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack(alignment: .top) {
                SectionHeader(
                    title: "여행자 리뷰",
                    subtitle: "다녀온 여행자들의 생생한 후기"
                )
                sortMenu
            }

            ForEach(viewModel.reviews) { review in
                ReviewCard(review: review)
                    .onAppear {
                        // 마지막 카드가 보이면 다음 페이지 로드 (무한 스크롤)
                        Task { await viewModel.loadMoreReviewsIfNeeded(after: review, using: feedService) }
                    }
            }

            if viewModel.isLoadingMoreReviews {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
            }
        }
    }

    // 시스템 Menu는 스크롤 뷰 안에서 라벨이 플로팅 레이어에 남아
    // 스크롤과 어긋나게 움직이는 버그가 있어 버튼 + 팝오버로 구현한다.
    private var sortMenu: some View {
        Button {
            isSortPickerPresented = true
        } label: {
            HStack(spacing: 5) {
                Text(viewModel.reviewSort.rawValue)
                    .font(.pretendard(14, .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.deepGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isSortPickerPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ReviewSort.allCases, id: \.self) { sort in
                    Button {
                        isSortPickerPresented = false
                        Task { await viewModel.selectSort(sort, using: feedService) }
                    } label: {
                        HStack {
                            Text(sort.rawValue)
                                .font(.chip14)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if sort == viewModel.reviewSort {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.deepGreen)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sort == viewModel.reviewSort ? .isSelected : [])
                }
            }
            .frame(minWidth: 130)
            .padding(.vertical, 4)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("리뷰 정렬: \(viewModel.reviewSort.rawValue)순")
    }
}

#Preview {
    HomeView()
}
