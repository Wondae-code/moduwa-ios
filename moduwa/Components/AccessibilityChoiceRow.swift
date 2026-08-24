import SwiftUI

/// "어떤 접근성이 필요한가/좋았나"를 고르는 한 줄. 게시글 작성(`PostAccessibilityPickerView`)과
/// 온보딩(`OnboardingView`)이 같은 줄을 쓴다 — 같은 질문을 두 화면이 다르게 생기면
/// 사용자는 두 번째 화면에서 다시 배워야 한다.
///
/// 선택을 **색만으로 전달하지 않는다** — 네모/체크 글리프와 글자 굵기가 함께 바뀐다.
struct AccessibilityChoiceRow: View {
    let feature: AccessibilityFeature
    let isOn: Bool
    let toggle: () -> Void

    /// 사람이 직접 고를 축. `flatPath`·`barrierFreeRoom` 은 서버 속성에서 파생되는 표시용
    /// 값이라 여기 없다(브랜드 가이드 아이콘 5종).
    static let choices: [AccessibilityFeature] = [
        .wheelchairAccessible, .visuallyImpairedFriendly, .hearingFriendly,
        .elderlyFriendly, .childFriendly,
    ]

    var body: some View {
        Button {
            withoutAnimation { toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(feature.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: feature.iconSize(height: 20).width, height: 20)
                    .foregroundStyle(isOn ? Color.deepGreen : Color.iconGray)

                Text(feature.label)
                    .font(.notoSans(15, isOn ? .bold : .regular))
                    .foregroundStyle(isOn ? Color.textPrimary : Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? Color.deepGreen : Color.iconGray)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feature.label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
