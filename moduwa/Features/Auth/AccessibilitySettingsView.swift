import SwiftUI

/// 접근성 — 앱 글자 크기와 고대비를 직접 조절하는 화면 (마이페이지 → 접근성).
///
/// 온보딩의 "내가 필요한 무장애"가 **추천 목록을 좁히는** 값이라면, 여기는 **화면 자체를 읽기
/// 편하게** 만드는 값이다. 접근성이 주제인 앱이니 자기 화면부터 키우고 또렷하게 할 수 있어야
/// 앞뒤가 맞는다. 두 값 모두 로그인과 무관하게 이 기기에 남는다(`AccessibilitySettings`).
///
/// 화면 하단 미리보기는 두 설정을 **바로** 반영한다 — 글자는 커지고, 고대비를 켜면 회색
/// 글자·경계선이 짙어진다. 무엇이 바뀌는지 눈으로 확인하고 정하게 하려는 것이다.
struct AccessibilitySettingsView: View {
    @Bindable private var settings = AccessibilitySettings.shared
    @State private var reader = SpeechReader.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                AuthHeader(
                    title: "접근성",
                    subtitle: "글자 크기·대비·읽어주기 속도를 앱에서 직접 조절해요. 시스템 손쉬운 사용 설정과 별개로 저장돼요."
                )

                textSizeSection
                highContrastSection
                speechSection
                previewSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, Spacing.xl)
        }
        .background(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 글자 크기

    /// 슬라이더(0…단계수-1)와 `TextScale` 을 잇는다. 슬라이더는 실수라 반올림해 단계로 스냅한다.
    private var scaleBinding: Binding<Double> {
        Binding(
            get: { Double(settings.textScale.rawValue) },
            set: { settings.textScale = TextScale(rawValue: Int($0.rounded())) ?? .system }
        )
    }

    private var textSizeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                sectionLabel("글자 크기")
                Spacer()
                // 지금 단계를 값으로 보여준다 — 슬라이더만으로는 어디에 서 있는지 애매하다.
                Text(settings.textScale.label)
                    .font(.notoSans(14, .medium))
                    .foregroundStyle(.deepGreen)
            }

            // 양 끝의 '가'로 크기 방향을 알린다(아이폰 손쉬운 사용 글자 크기 슬라이더와 같은 결).
            HStack(spacing: Spacing.m) {
                Text("가")
                    .font(.notoSans(14))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
                Slider(
                    value: scaleBinding,
                    in: 0...Double(TextScale.allCases.count - 1),
                    step: 1
                )
                .tint(.deepGreen)
                .accessibilityLabel("글자 크기")
                .accessibilityValue(settings.textScale.label)
                Text("가")
                    .font(.notoSans(26))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }

            Text("‘시스템’은 아이폰 설정의 글자 크기를 그대로 따라요. 오른쪽으로 갈수록 크게 보여드려요.")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 고대비

    private var highContrastSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("고대비")

            Toggle(isOn: $settings.highContrast) {
                Text("고대비 켜기")
                    .font(.notoSans(15, .medium))
                    .foregroundStyle(.textPrimary)
            }
            .tint(.deepGreen)
            .padding(Spacing.l)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(Color.photoPlaceholder))

            Text("흐린 회색 글자·경계선·오류색을 더 진하게 표시해 또렷하게 보여드려요. 색만으로 뜻을 전하지 않도록 아이콘·글자도 함께 쓰여요.")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: settings.highContrast) { _, on in
            UIAccessibility.post(notification: .announcement, argument: on ? "고대비 켬" : "고대비 끔")
        }
    }

    // MARK: - 읽어주기

    private var rateBinding: Binding<Double> {
        Binding(
            get: { Double(settings.speechRate.rawValue) },
            set: { settings.speechRate = SpeechRate(rawValue: Int($0.rounded())) ?? .normal }
        )
    }

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                sectionLabel("읽어주기 속도")
                Spacer()
                Text(settings.speechRate.label)
                    .font(.notoSans(14, .medium))
                    .foregroundStyle(.deepGreen)
            }

            HStack(spacing: Spacing.m) {
                Image(systemName: "tortoise.fill")
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
                Slider(
                    value: rateBinding,
                    in: 0...Double(SpeechRate.allCases.count - 1),
                    step: 1
                )
                .tint(.deepGreen)
                .accessibilityLabel("읽어주기 속도")
                .accessibilityValue(settings.speechRate.label)
                Image(systemName: "hare.fill")
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }

            // 속도는 **들어 봐야** 안다. 숫자나 라벨만으로는 고를 수 없다.
            Button {
                let id = "settings-preview"
                if reader.isReading(id) {
                    reader.stop()
                } else {
                    reader.speak(["바뀐 속도로 이렇게 읽어드려요. 장소 상세에서 읽어주기를 누르면 무장애 정보부터 읽어드립니다."],
                                 id: id)
                }
            } label: {
                Label(reader.isReading("settings-preview") ? "멈추기" : "들어보기",
                      systemImage: reader.isReading("settings-preview") ? "stop.fill" : "play.fill")
                    .font(.notoSans(14, .bold))
                    .foregroundStyle(.deepGreen)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(Color.deepGreen, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text("장소 상세의 ‘읽어주기’가 이 속도로 읽어드려요. 아이폰 설정 → 손쉬운 사용 → 음성 콘텐츠에서 더 자연스러운 한국어 음성을 받으면 함께 좋아져요.")
                .font(.notoSans(13))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        // 속도를 바꾸면 듣던 것을 멈춘다 — 이미 만들어진 발화는 옛 속도로 끝까지 읽는다.
        .onChange(of: settings.speechRate) { _, _ in reader.stop() }
        .onDisappear { reader.stop(ifReading: "settings-preview") }
    }

    // MARK: - 미리보기

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("미리보기")

            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.deepGreen)
                    Text("무장애 여행 카드")
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                }

                Text("이 카드의 글자 크기와 색이 위 설정에 따라 바로 바뀝니다.")
                    .font(.body15)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.iconGray)
                    Text("보조 정보 · 비활성 아이콘 예시")
                        .font(.meta13)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.card).fill(.white))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
        // 이 화면은 루트에서 이미 글자 크기를 물려받지만, 미리보기만은 한 번 더 못 박아
        //  전환이 확실히 즉시 보이게 한다(같은 값이라 중복 적용은 무해하다).
        .applyTextScale(settings.textScale)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.notoSans(16, .bold, relativeTo: .headline))
            .foregroundStyle(.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("접근성 설정") {
    NavigationStack {
        AccessibilitySettingsView()
    }
}
