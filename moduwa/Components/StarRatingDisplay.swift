import SwiftUI

/// 표시용 별점 (읽기 전용). 입력용은 `StarRatingInput`.
///
/// 접근성 판단 1 — 색이 아니라 **형태**로 구분:
/// 채운 별은 면(`star`, 딥그린), 빈 별은 테두리 별(`star_outline`, 회색)로 그린다.
/// 같은 모양에 색만 바꾸면 색각 이상·저대비·흑백 인쇄 환경에서 몇 점인지 전달되지 않는다.
/// `StarRatingInput`과 같은 규칙을 쓴다.
///
/// 접근성 판단 2 — 단일 요소:
/// 별 5개를 각각 노출하면 VoiceOver가 다섯 번 멈추면서도 "몇 점인지"는 알려 주지 않는다.
/// 컨테이너를 하나로 묶고 점수를 `accessibilityValue`로 읽어 준다.
/// 주변 텍스트(평균 점수·후기 수·날짜)와 한 문장으로 읽어야 하는 자리에서는 `isAccessible`을
/// 끄고 상위 컨테이너가 라벨을 만든다.
struct StarRatingDisplay: View {
    /// 0~5. 반올림해 채울 개수를 정한다.
    let rating: Double
    /// 시안 노드별 별 크기 — 전체 평점(333:1337) 16, 개별 리뷰(333:1434) 13, 이름 옆(249:741) 16
    var starSize: CGFloat = 16
    var spacing: CGFloat = 2.5
    var isAccessible = true

    /// 옆에 붙는 숫자·날짜와 같은 비율로 커져야 줄이 어긋나지 않는다.
    /// 다만 별 5개가 한 줄에 들어가야 해서 상한을 둔다(`StarRatingInput`과 같은 판단).
    @ScaledMetric(relativeTo: .footnote) private var typeScale: CGFloat = 1

    private var scale: CGFloat { min(typeScale, 1.8) }
    private var filled: Int { min(max(Int(rating.rounded()), 0), 5) }

    var body: some View {
        HStack(spacing: spacing * scale) {
            ForEach(1...5, id: \.self) { value in
                Image(value <= filled ? "star" : "star_outline")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: starSize * scale, height: starSize * scale)
                    .foregroundStyle(value <= filled ? Color.deepGreen : .iconGray)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("별점")
        .accessibilityValue("5점 중 \(filled)점")
        .accessibilityHidden(!isAccessible)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ForEach([0.0, 2.4, 3.5, 4.3, 5.0], id: \.self) { value in
            HStack(spacing: 8) {
                Text(value, format: .number.precision(.fractionLength(1)))
                    .font(.notoSans(14, .medium))
                StarRatingDisplay(rating: value)
            }
        }
        StarRatingDisplay(rating: 4, starSize: 13, spacing: 1.6)
    }
    .padding(24)
}
