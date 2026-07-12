import SwiftUI

/// 장소 카드 좌상단의 접근성 뱃지 (휠체어 접근 / 평탄 동선 / 무장애 객실).
/// 평소엔 아이콘만 보이고, 탭하면 펼쳐지며 라벨을 보여준다. 다시 탭하면 접힌다.
struct AccessibilityBadge: View {
    let feature: AccessibilityFeature
    @State private var isExpanded: Bool

    init(feature: AccessibilityFeature, initiallyExpanded: Bool = false) {
        self.feature = feature
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                ISAWheelchairIcon(size: 13)
                if isExpanded {
                    Text(feature.label)
                        .font(.caption12)
                        .fontWeight(.semibold)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.deepGreen)
            .padding(.horizontal, isExpanded ? 10 : 7)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white))
            .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("접근성: \(feature.label)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AccessibilityBadge(feature: .wheelchairAccessible)
        AccessibilityBadge(feature: .wheelchairAccessible, initiallyExpanded: true)
        AccessibilityBadge(feature: .flatPath, initiallyExpanded: true)
        AccessibilityBadge(feature: .barrierFreeRoom, initiallyExpanded: true)
    }
    .padding()
    .background(Color.appBackground)
}
