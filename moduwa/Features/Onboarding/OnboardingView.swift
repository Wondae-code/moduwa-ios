import SwiftUI

/// 첫 실행 온보딩 — "어떤 접근성이 필요한가"를 묻는다.
///
/// 여기서 고른 값은 **기기에 저장되고, 가입할 때 계정으로 올라간다**
/// (`OnboardingProfileStore` → `POST /v1/auth/email/sign-up`). 가입 전에는 서버에 아무것도
/// 만들지 않는다 — 그래서 "가입했더니 내 것이 사라졌다"가 생기지 않는다.
///
/// **가입을 요구하지 않는다.** 앱의 가치를 확인하기 전에 계정 벽을 만나면 대부분 떠나고,
/// 계정과 무관한 기능(무장애 장소 찾기)에 로그인을 강제하면 앱스토어 심사에서도 걸린다.
/// 로그인은 글을 쓰거나 저장할 때 처음 묻는다.
struct OnboardingView: View {
    /// 온보딩을 마쳤다(고른 것이 없어도 마친 것이다).
    var onFinish: () -> Void

    @State private var selection: [AccessibilityFeature] = OnboardingProfileStore.shared.features

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Image("logo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                        .foregroundStyle(.deepGreen)
                        .padding(.bottom, Spacing.s)
                        .accessibilityHidden(true)

                    Text("어떤 접근성이 필요하세요?")
                        .font(.heroTitle)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("고른 정보는 장소를 고를 때 참고하고, 가입하면 계정에 저장돼 기기를 바꿔도 따라옵니다. 지금 고르지 않아도 괜찮아요.")
                        .font(.notoSans(14, relativeTo: .subheadline))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        ForEach(AccessibilityChoiceRow.choices, id: \.self) { feature in
                            AccessibilityChoiceRow(
                                feature: feature,
                                isOn: selection.contains(feature)
                            ) {
                                if selection.contains(feature) {
                                    selection.removeAll { $0 == feature }
                                } else {
                                    selection.append(feature)
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.card)
                        .fill(Color.photoPlaceholder))
                    .padding(.top, Spacing.s)
                }
                .padding(.horizontal, 24)
                .padding(.top, Spacing.xxl)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(.white)
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var footer: some View {
        VStack(spacing: Spacing.m) {
            AuthPrimaryButton(title: selection.isEmpty ? "시작하기" : "\(selection.count)개 선택하고 시작하기") {
                finish()
            }

            Button {
                // 건너뛰기도 **완료로 기록한다** — 그러지 않으면 앱을 켤 때마다 다시 묻는다.
                finish()
            } label: {
                Text("나중에 고를래요")
                    .font(.notoSans(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Spacing.m)
        .background(.white)
    }

    private func finish() {
        OnboardingProfileStore.shared.finish(selection)
        UIAccessibility.post(notification: .announcement, argument: "설정을 저장했어요")
        onFinish()
    }
}

#Preview("온보딩") {
    OnboardingView(onFinish: {})
}
