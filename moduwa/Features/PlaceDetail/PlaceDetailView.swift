import SwiftUI

/// 장소 상세 (Figma "추천장소 B")
struct PlaceDetailView: View {
    let place: Place

    @Environment(\.feedService) private var feedService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var detail: PlaceDetail?
    @State private var isOverviewExpanded = false
    /// 사진 위 원형 뱃지 중 선택된 유형 — 선택 시에만 안내 칩을 띄운다
    @State private var selectedFeature: AccessibilityFeature?
    /// 카카오맵 엔진은 지도 영역이 화면에 나타난 뒤 활성화해야 한다
    @State private var isMapVisible = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 0) {
                    photoSection
                    actionButtons

                    VStack(alignment: .leading, spacing: 0) {
                        titleRow
                            .padding(.top, 22)
                        ratingRow
                            .padding(.top, 8)
                        overviewSection
                    }
                    .padding(.horizontal, 32)

                    if let info = detail?.info, !info.isEmpty {
                        sectionDivider
                        basicInfoSection
                            .padding(.horizontal, 32)
                    }

                    sectionDivider
                    mapSection
                    sectionDivider
                    extraInfoSection
                        .padding(.horizontal, 32)
                        .padding(.bottom, Spacing.xxl)
                }
            }
            .background(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { detail = try? await feedService.fetchPlaceDetail(contentId: place.id) }
    }

    // MARK: - 헤더 (뒤로가기 + 타이틀 + 지도/메뉴)

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 25, height: 25)
            }
            .accessibilityLabel("뒤로")

            Text("장소 상세")
                .font(.pretendard(20, .bold))
                .padding(.leading, 12)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if let url = detail?.kakaoMapURL { openURL(url) }
                } label: {
                    Image("detail_map")
                        .renderingMode(.template)
                        .frame(width: 26, height: 26)
                }
                .accessibilityLabel("지도에서 보기")

                Button {} label: {
                    Image("hamburger")
                        .renderingMode(.template)
                        .frame(width: 26, height: 26)
                }
                .accessibilityLabel("메뉴")
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.leading, 28)
        .padding(.trailing, 27)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.cardStroke).frame(height: 1)
        }
    }

    // MARK: - 사진 (+ 접근성 뱃지, 안내 칩)

    private var photoSection: some View {
        Color.clear
            .frame(height: 227)
            .overlay {
                if let imageURL = detail?.imageURL ?? place.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        PhotoPlaceholder()
                    }
                } else {
                    PhotoPlaceholder()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 10) {
                    // 선택된 뱃지의 안내만 칩으로 표시
                    if let group = detail?.accessibilityGroups.first(where: { $0.feature == selectedFeature }),
                       let note = group.notes.first {
                        Text("• \(note)")
                            .font(.pretendard(15, .medium))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.85)))
                            .transition(.opacity)
                    }
                    HStack(spacing: 9) {
                        ForEach(detail?.accessibilityFeatures ?? [], id: \.self) { feature in
                            photoBadgeButton(feature)
                        }
                    }
                }
                .padding(.trailing, 26)
                .padding(.bottom, 15)
            }
    }

    /// 사진 위 원형 접근성 뱃지 버튼 — 탭하면 해당 유형의 안내 칩을 토글한다
    private func photoBadgeButton(_ feature: AccessibilityFeature) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFeature = selectedFeature == feature ? nil : feature
            }
        } label: {
            photoBadge(feature)
                .overlay(
                    Circle().stroke(selectedFeature == feature ? Color.moduwaGreen : .white, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("접근성: \(feature.label)")
        .accessibilityHint("안내 보기")
        .accessibilityAddTraits(selectedFeature == feature ? .isSelected : [])
    }

    /// 딥그린 원 + 흰 아이콘 (34pt)
    private func photoBadge(_ feature: AccessibilityFeature) -> some View {
        Circle()
            .fill(Color.deepGreen)
            .frame(width: 34, height: 34)
            .overlay {
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .accessibilityLabel(feature.label)
    }

    // MARK: - 액션 버튼 (저장·일정추가·후기쓰기·공유)

    private var actionButtons: some View {
        HStack(spacing: 0) {
            actionButton(title: "저장하기", icon: "detail_bookmark") {}
            actionButton(title: "일정추가", icon: "detail_plus") {}
            actionButton(title: "후기쓰기", icon: "detail_pencil") {}
            actionButton(title: "공유하기", icon: "detail_share") {}
        }
        .padding(.vertical, 14)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.deepGreen)
                Text(title)
                    .font(.pretendard(13, .semiBold))
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .overlay(Rectangle().stroke(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 이름·주소·별점

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(detail?.name ?? place.name)
                .font(.pretendard(22, .bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
            Text(detail?.address ?? place.region)
                .font(.pretendard(14))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var ratingRow: some View {
        if let rating = detail?.rating {
            HStack(spacing: 8) {
                Text(rating, format: .number.precision(.fractionLength(1)))
                    .font(.pretendard(14, .medium))
                HStack(spacing: 2.5) {
                    ForEach(0..<5, id: \.self) { i in
                        Image("star")
                            .renderingMode(.template)
                            .foregroundStyle(Double(i) < rating.rounded() ? .deepGreen : .cardStroke)
                    }
                }
                if let count = detail?.reviewCount {
                    Text("(\(count))")
                        .font(.pretendard(14))
                }
            }
            .foregroundStyle(.textPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("평점 \(rating.formatted(.number.precision(.fractionLength(1))))점, 리뷰 \(detail?.reviewCount ?? 0)개")
        }
    }

    // MARK: - 설명

    @ViewBuilder
    private var overviewSection: some View {
        if let overview = detail?.overview {
            Text(overview)
                .font(.pretendard(14))
                .foregroundStyle(.textSecondary)
                .lineSpacing(6)
                .lineLimit(isOverviewExpanded ? nil : 6)
                .padding(.top, 22)

            if !isOverviewExpanded {
                LoadMoreButton(title: "설명 더보기") {
                    withAnimation { isOverviewExpanded = true }
                }
                .padding(.top, 18)
            }
        }
    }

    // MARK: - 기본정보

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("기본정보")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(detail?.info ?? []) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("•  \(row.label)")
                            .font(.pretendard(16, .semiBold))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 110, alignment: .leading)
                        if row.isLink, let url = URL(string: row.value) {
                            Link(row.value, destination: url)
                                .font(.pretendard(14))
                                .foregroundStyle(.deepGreen)
                                .underline()
                                .lineLimit(1)
                        } else {
                            Text(row.value)
                                .font(.pretendard(14))
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 지도

    private var mapSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Group {
                if let latitude = detail?.latitude, let longitude = detail?.longitude,
                   Secrets.kakaoNativeAppKey != nil {
                    // 임베드 카카오맵 — 보기 전용, 제스처는 스크롤에 양보하고 조작은 카카오맵 앱으로
                    KakaoMapView(latitude: latitude, longitude: longitude, draw: $isMapVisible)
                        .onAppear { isMapVisible = true }
                        .onDisappear { isMapVisible = false }
                        .allowsHitTesting(false)
                        .overlay {
                            // 중심 좌표 핀 (끝점이 중심을 가리키도록 절반 올림)
                            Image("location_on")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.deepGreen)
                                .offset(y: -15)
                        }
                        .accessibilityLabel("\(detail?.name ?? place.name) 위치 지도")
                } else {
                    Rectangle()
                        .fill(.white)
                        .overlay(
                            Text("지도")
                                .font(.pretendard(24, .bold))
                                .foregroundStyle(.textPrimary)
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 126)
            .overlay(Rectangle().stroke(Color.cardStroke, lineWidth: 1))
            .padding(.horizontal, 52)

            Button {
                if let url = detail?.kakaoMapURL { openURL(url) }
            } label: {
                HStack(spacing: 4) {
                    Image("kakao_map")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("카카오맵에서 보기")
                        .font(.pretendard(14))
                        .foregroundStyle(.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 52)
            .disabled(detail?.kakaoMapURL == nil)
            .accessibilityLabel("카카오맵에서 보기")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 추가정보 (접근성 뱃지·안내·주의 칩)

    private var extraInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추가정보")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 9) {
                ForEach(detail?.accessibilityFeatures ?? [], id: \.self) { feature in
                    photoBadge(feature)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail?.accessibilityNotes ?? [], id: \.self) { note in
                    Text("•  \(note)")
                        .font(.pretendard(15, .medium))
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(4)
                }
            }

            if let tags = detail?.cautionTags, !tags.isEmpty {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.pretendard(14, .semiBold))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.moduwaGreen))
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.cardStroke)
            .frame(height: 1)
            .padding(.vertical, 24)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: MockData.recommendedPlaces[0])
    }
}
