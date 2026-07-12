import SwiftUI

/// 홈 피드 (Figma "메인화면")
struct HomeView: View {
    @Environment(\.feedService) private var feedService
    @State private var viewModel = HomeViewModel()
    @State private var isSortPickerPresented = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topSection
                recommendationSection
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.xl)

                Rectangle()
                    .fill(Color.appBackground)
                    .frame(height: 8)
                    .accessibilityHidden(true)

                reviewSection
                    .padding(.horizontal, Spacing.l)
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

            HStack(spacing: 18) {
                Button {} label: {
                    Image("search")
                        .renderingMode(.template)
                }
                .accessibilityLabel("검색")

                Button {} label: {
                    // 알림 벨 에셋은 아직 미제공 — SF Symbol 유지
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .medium))
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(.brandGreen).frame(width: 6, height: 6)
                        }
                }
                .accessibilityLabel("알림, 새 알림 있음")

                Button {} label: {
                    Image("hamburger")
                        .renderingMode(.template)
                }
                .accessibilityLabel("메뉴")
            }
            .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, 10)
    }

    // MARK: - 상단 (헤더 + 히어로, 배경 공유)

    private var heroGradientTop: Color {
        Color(hex: 0xE0F3A6)
    }

    /// 헤더와 히어로 카드가 하나의 그라데이션 배경을 공유하며 함께 스크롤된다.
    private var topSection: some View {
        VStack(spacing: 0) {
            headerBar
            if let hero = viewModel.hero {
                HeroCard(recommendation: hero)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xl)
            }
        }
        .background(
            LinearGradient(
                colors: [heroGradientTop, Color(hex: 0xF3FADC), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(alignment: .top) {
            // 상태바 뒤와 오버스크롤(바운스) 영역까지 배경이 이어지도록 위로 연장
            heroGradientTop
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { category in
                        CategoryChip(category: category, isSelected: category == viewModel.selectedCategory) {
                            Task { await viewModel.selectCategory(category, using: feedService) }
                        }
                    }
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.places) { place in
                    PlaceCard(place: place)
                }
            }

            Button {
                // TODO: 추천 더보기
            } label: {
                HStack(spacing: 6) {
                    Text("맞춤 추천 더보기")
                        .font(.pretendard(15, .semiBold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.deepGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .stroke(Color.cardStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
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
            }
        }
    }

    // 시스템 Menu는 스크롤 뷰 안에서 라벨이 플로팅 레이어에 남아
    // 스크롤과 어긋나게 움직이는 버그가 있어 버튼 + 팝오버로 구현한다.
    private var sortMenu: some View {
        Button {
            isSortPickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.reviewSort.rawValue)
                    .font(.chip14)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
