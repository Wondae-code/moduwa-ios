import SwiftUI

/// 별점 입력 (1~5). 장소 상세의 표시용 별(`PlaceDetailView.ratingRow`)과 같은 브랜드 별 아이콘을 쓰고
/// 크기만 입력용(28pt)으로 키웠다. 후기 작성 시안은 미확보 — 확정 시 크기·간격이 바뀔 수 있다.
///
/// 접근성 판단 1 — 단일 조절 요소:
/// 별 5개를 각각 버튼으로 노출하면 VoiceOver가 요소 5개를 훑게 되고, "지금 몇 점인지"는
/// 어느 버튼에도 담기지 않아 사용자가 직접 세어야 한다. 그래서 컨테이너를 하나의 요소로 묶고
/// (`children: .ignore`) `accessibilityValue` + `accessibilityAdjustableAction`(위아래 스와이프)으로
/// 조절하게 한다. 터치 사용자는 그대로 원하는 별을 직접 눌러 한 번에 선택할 수 있다.
///
/// 검증 메모: 시뮬레이터 뷰 스냅샷(XCUI 계열 덤프)에는 SwiftUI가 합성한 컨테이너 요소가
/// 나타나지 않고 자식 Image만 보인다. 즉 이 구조는 자동화 덤프로 확인할 수 없으니,
/// 실제 VoiceOver를 켜고 "별점 / 5점 중 N점" 한 요소로 읽히는지 한 번 확인해야 한다.
///
/// 접근성 판단 2 — 색이 아닌 형태로 구분:
/// 채운 별은 면(딥그린), 빈 별은 같은 외곽선의 테두리 별(`star_outline`)로 그린다.
/// 표시용 별점은 같은 모양에 색만 바꿔 쓰지만(장소 상세), 입력은 "내가 몇 점을 골랐는지"가
/// 유일한 상태값이라 색각 이상·저대비 환경에서도 읽혀야 한다.
struct StarRatingInput: View {
    @Binding var rating: Int

    static let maxRating = 5

    /// 점수별 설명. 화면 문구와 VoiceOver 값이 같은 문장을 쓰도록 여기서 한 번만 정의한다.
    static func label(for rating: Int) -> String {
        switch rating {
        case 1: "별로예요"
        case 2: "아쉬워요"
        case 3: "보통이에요"
        case 4: "좋아요"
        case 5: "아주 좋아요"
        default: "별점을 선택해 주세요"
        }
    }

    @ScaledMetric(relativeTo: .title3) private var scaledStar: CGFloat = 28

    /// 별 5개가 한 줄에 들어가야 하므로 Dynamic Type 확대에 상한을 둔다.
    /// (AX5에서 무제한으로 키우면 5 × 폭이 화면을 넘어 잘린다)
    private var starSize: CGFloat { min(scaledStar, 40) }
    /// 별 사이 간격. 히트 영역을 별 오른쪽으로 이 폭만큼 늘려 44pt 터치 영역을 만든다.
    private var starGap: CGFloat { max(44 - starSize, 16) }
    private var verticalPadding: CGFloat { max((44 - starSize) / 2, 4) }

    var body: some View {
        // 별을 Button 5개로 두지 않고 Image 5개 + 컨테이너 제스처로 만든다.
        // `children: .ignore`는 상호작용 가능한(포커스 가능한) 자식까지 확실히 지워 주지 못해서,
        // Button으로 두면 별 5개가 각각 포커스 정지점으로 남아 컨테이너의 별점 값·조절 액션이 묻힐 수 있다.
        // 자식을 순수 Image로 두면 단일 요소가 보장된다. 부수 효과로 별 위를 문질러 점수를 바꾸는 조작도 얻는다.
        // (자식에 accessibilityHidden을 겹쳐 둔 것은 혹시 컨테이너가 우회되더라도
        //  에셋 이름 "star_outline"이 라벨로 새지 않게 하는 이중 안전장치다)
        //
        // 히트 영역은 별의 좌우가 아니라 오른쪽으로만 넓힌다. 좌우로 균등하게 넓히면
        // 첫 별이 안쪽으로 밀려 섹션 제목(마진 24)과 왼쪽 선이 어긋난다.
        HStack(spacing: 0) {
            ForEach(1...Self.maxRating, id: \.self) { value in
                star(filled: value <= rating)
                    .padding(.trailing, starGap)
                    .padding(.vertical, verticalPadding)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            // minimumDistance 0 — 탭과 드래그를 한 제스처로 받는다.
            //
            // ⚠️ 손가락이 닿는 즉시(translation .zero) 값을 바꾸면 안 된다.
            // 이 컨트롤은 스크롤 뷰 한가운데 놓이는데(장소 상세·장소 후기의 "방문 후기를 남겨주세요!"),
            // 별 위에서 시작한 세로 스크롤까지 별점 선택으로 먹어 버려 작성 시트가 멋대로 열린다.
            // 그래서 ① 가로로 움직인 드래그(문질러 고르기)와 ② 손을 뗀 탭에서만 값을 정한다.
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isHorizontalScrub(value.translation) else { return }
                    rating = ratingValue(atX: value.location.x)
                }
                .onEnded { value in
                    // 세로로 끌고 간 손가락은 스크롤이었다 — 뗄 때도 값을 바꾸지 않는다
                    guard isHorizontalScrub(value.translation) || isTap(value.translation) else { return }
                    rating = ratingValue(atX: value.location.x)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("별점")
        .accessibilityValue(
            rating == 0
                ? "선택하지 않음"
                : "5점 중 \(rating)점, \(Self.label(for: rating))"
        )
        .accessibilityHint("위아래로 스와이프해 별점을 조절합니다")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, Self.maxRating)
            case .decrement: rating = max(rating - 1, 1)
            @unknown default: break
            }
        }
        // 폭을 스스로 넓히지 않는다 — 별 5개의 고유 크기만 차지하고, 좌·중앙 정렬은
        // 호출부가 정한다. (자기 정렬을 강제하면 가운데 두고 싶은 화면에서 되돌릴 수 없다)
    }

    /// 별 위를 문질러 고르는 동작인지 (가로 이동이 세로보다 확실히 우세할 때만)
    private func isHorizontalScrub(_ translation: CGSize) -> Bool {
        abs(translation.width) > 6 && abs(translation.width) > abs(translation.height)
    }

    /// 제자리 탭인지 — 손가락이 거의 움직이지 않았으면 탭이다
    private func isTap(_ translation: CGSize) -> Bool {
        abs(translation.width) < 10 && abs(translation.height) < 10
    }

    /// 컨테이너 로컬 x좌표가 몇 번째 별인지
    private func ratingValue(atX x: CGFloat) -> Int {
        let itemWidth = starSize + starGap
        return min(max(Int(x / itemWidth) + 1, 1), Self.maxRating)
    }

    private func star(filled: Bool) -> some View {
        Image(filled ? "star" : "star_outline")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: starSize, height: starSize)
            .foregroundStyle(filled ? Color.deepGreen : .iconGray)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        ForEach(0...5, id: \.self) { StarRatingInput(rating: .constant($0)) }
    }
    .padding(24)
}
