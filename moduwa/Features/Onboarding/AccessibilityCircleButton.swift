import SwiftUI

/// 온보딩 "무장애정보입력" 의 원형 선택 버튼 (시안 868:281 / 868:317 의 `icon` 60×60).
///
/// 시안 값 그대로: 비선택은 **흰 원 + 딥그린 보더 1 + 딥그린 픽토그램**, 선택은
/// **딥그린 원 + 흰 픽토그램**. 둘 다 옅은 그림자가 있다.
///
/// 픽토그램은 [[브랜드 가이드]] 아이콘 5종(`access_*`)을 그대로 쓴다 — 무장애 아이콘은 다른
/// 화면·소스에서 따로 가져오지 않는다는 규칙이 있고, 원 안에 넣는 높이만 시안에서 읽어 왔다.
struct AccessibilityCircleButton: View {
    let feature: AccessibilityFeature
    let isOn: Bool
    let toggle: () -> Void

    /// 원 지름 60 안에서의 픽토그램 높이. 아이콘마다 다르다 —
    /// 종횡비가 달라 한 비율로 맞추면 청각(정사각)만 작아 보인다(시안 실측값).
    private var glyphHeight: CGFloat {
        switch feature {
        case .wheelchairAccessible, .flatPath, .barrierFreeRoom: 33
        case .visuallyImpairedFriendly: 30
        case .hearingFriendly: 35
        case .elderlyFriendly: 35
        case .childFriendly: 33
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { withoutAnimation { toggle() } }) {
                Circle()
                    .fill(isOn ? Color.deepGreen : .white)
                    .overlay(Circle().stroke(Color.deepGreen, lineWidth: isOn ? 0 : 1))
                    .overlay {
                        let size = feature.iconSize(height: glyphHeight)
                        Image(feature.iconName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)
                            .foregroundStyle(isOn ? Color.white : Color.deepGreen)
                    }
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.deepGreen.opacity(0.12), radius: 5, y: 2)
            }
            .buttonStyle(.plain)

            Text(feature.selfLabel)
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.deepGreen)
        }
        // 원과 라벨을 한 요소로 묶는다 — 나눠 두면 VoiceOver 가 그림과 글자를 따로 읽는다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feature.selfLabel)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// 같은 줄의 "해당없음" (시안 868:310 / 868:346).
///
/// 다섯 항목과 **다르게 회색**이다 — 고르는 것이 아니라 "고를 것이 없다"는 답이라서
/// 시안이 색으로 구분했다. 이걸 누르면 나머지 선택이 모두 풀린다.
struct AccessibilityNoneButton: View {
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: { withoutAnimation { toggle() } }) {
                Circle()
                    .fill(isOn ? Color.iconGray : .white)
                    .overlay(Circle().stroke(Color.iconGray, lineWidth: 1))
                    .overlay {
                        // 시안의 Line 9 — 길이 43, 두께 5의 사선.
                        Capsule()
                            .fill(isOn ? Color.white : Color.iconGray)
                            .frame(width: 43, height: 5)
                            .rotationEffect(.degrees(45))
                    }
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.deepGreen.opacity(0.12), radius: 5, y: 2)
            }
            .buttonStyle(.plain)

            Text("해당없음")
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("해당없음")
        .accessibilityHint("고른 항목을 모두 지웁니다")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("무장애 원형 선택") {
    HStack(spacing: 20) {
        AccessibilityCircleButton(feature: .wheelchairAccessible, isOn: false) {}
        AccessibilityCircleButton(feature: .elderlyFriendly, isOn: true) {}
        AccessibilityNoneButton(isOn: false) {}
    }
    .padding(40)
}
