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

    let feature: AccessibilityFeature
    var style: Style = .filled
    @State private var isExpanded: Bool

    init(feature: AccessibilityFeature, style: Style = .filled, initiallyExpanded: Bool = false) {
        self.feature = feature
        self.style = style
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                if isExpanded {
                    Text(feature.label)
                        .font(.caption12)
                        .fontWeight(.semibold)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(style == .filled ? Color.white : .deepGreen)
            .padding(.horizontal, isExpanded ? 10 : 7)
            .padding(.vertical, 7)
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
