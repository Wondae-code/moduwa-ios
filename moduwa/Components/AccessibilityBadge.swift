import SwiftUI

/// 사진 좌상단의 접근성 뱃지 (Figma: 원형 아이콘 뱃지, 접근성 아이콘 5종).
/// 평소엔 아이콘만 보이고, 탭하면 펼쳐지며 라벨을 보여준다. 다시 탭하면 접힌다.
struct AccessibilityBadge: View {
    enum Style {
        /// deepGreen 원 + 흰 아이콘 — 장소 카드
        case filled
        /// 흰 원 + deepGreen 아이콘 — 리뷰 사진
        case inverted
    }

    /// 뱃지 원의 지름 — 시안 `873:1726` 의 홈 장소 카드 뱃지가 **27** 이다.
    /// (같은 뱃지가 자리마다 크기가 다르다: 추가정보 28.3, 장소 상세 대표 사진 34.)
    private static let diameter: CGFloat = 27

    let feature: AccessibilityFeature
    var style: Style = .filled
    @State private var isExpanded: Bool

    init(feature: AccessibilityFeature, style: Style = .filled, initiallyExpanded: Bool = false) {
        self.feature = feature
        self.style = style
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var iconSize: CGSize { feature.iconSize(inBadgeDiameter: Self.diameter) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                // ⚠️ **높이를 못 박지 않는다.** 예전에는 높이 14 로 고정했는데, 그러면 세로로
                //  긴 그림(지체·유아)은 폭이 10 밑으로 내려가 원 안에서 유독 작아 보였다
                //  — 시안 대비 76% 였다(2026-09-07 지적).
                //
                //  시안은 네 아이콘을 **모두 같은 배율(0.795)** 로 줄여 넣는다. 브랜드 가이드
                //  픽토그램들이 대각선 ~27.5 로 맞춰져 있어서, 대각선을 기준으로 재면 그 규칙이
                //  그대로 나온다 — `iconSize(inBadgeDiameter:)` 가 지름의 **0.82** 를 대각선으로
                //  삼는데, 시안도 22/27 = 0.815 다. 세로로 긴 그림도 짧은 그림도 원 안에서
                //  같은 무게로 보이는 것이 목적이다.
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize.width, height: iconSize.height)
                if isExpanded {
                    Text(feature.label)
                        // 커스텀 폰트는 .fontWeight로 굵기가 안 바뀐다 — SemiBold 페이스를 직접 지정
                        .font(.notoSans(12, .semiBold))
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(style == .filled ? Color.white : .deepGreen)
            // ⚠️ **접힌 뱃지는 폭을 못 박는다.** 예전에는 좌우 7 패딩만 줬는데, 그러면 폭이
            //  **아이콘 비율을 따라간다** — 휠체어처럼 세로로 긴 그림은 폭 24 · 높이 28 이
            //  되어 원이 아니라 세로 타원으로 보였다(2026-09-07 지적). 다섯 아이콘의 비율이
            //  제각각이라 카드마다 뱃지 모양이 달라지기도 했다.
            //  높이(14 + 7 + 7 = 28)를 지름으로 삼으면 그림이 무엇이든 정원이 된다.
            .padding(.horizontal, isExpanded ? 10 : 0)
            .frame(width: isExpanded ? nil : Self.diameter)
            .frame(minHeight: Self.diameter)
            .fixedSize(horizontal: false, vertical: true)
            .background(Capsule().fill(style == .filled ? Color.deepGreen : .white))
            .shadow(color: .black.opacity(0.1), radius: 2.5, y: 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("접근성: \(feature.label)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            AccessibilityBadge(feature: .wheelchairAccessible)
            AccessibilityBadge(feature: .hearingFriendly)
            AccessibilityBadge(feature: .visuallyImpairedFriendly)
            AccessibilityBadge(feature: .elderlyFriendly)
            AccessibilityBadge(feature: .childFriendly)
        }
        AccessibilityBadge(feature: .wheelchairAccessible, style: .inverted)
        AccessibilityBadge(feature: .wheelchairAccessible, initiallyExpanded: true)
        AccessibilityBadge(feature: .childFriendly, initiallyExpanded: true)
    }
    .padding()
    .background(Color.photoPlaceholder)
}
