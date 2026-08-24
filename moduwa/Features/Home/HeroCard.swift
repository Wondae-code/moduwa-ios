import SwiftUI

/// 홈 상단의 맞춤 접근성 추천 카드.
///
/// 이름을 부르는 카드라 **로그인 여부가 그대로 보인다.** 계정이 있으면 그 사람의 닉네임을,
/// 없으면 이름 자리에 로그인 안내를 둔다 — 비로그인인데 아무 이름이나 부르면(예전에는 번들
/// 데이터의 "모두와 님") 카드가 개인화된 척을 하게 된다.
///
/// 이름은 **계정에서 온다**(`Account.nickname`). 화면이 세션을 직접 읽지 않고 받아 쓰는 이유는
/// 프리뷰에서 이 카드만 따로 그려 볼 수 있어야 하기 때문이다.
struct HeroCard: View {
    /// 로그인한 사람의 표시 이름. `nil` 이면 비로그인이다.
    var userName: String?
    /// 계정에 저장된 무장애 요소. **비어 있으면 그 줄을 아예 그리지 않는다** —
    /// 고르지 않은 사람에게 남의 기본값을 보여 주면 자기 것으로 오해한다.
    var accessFeatures: [AccessibilityFeature] = []
    /// 비로그인 상태의 CTA. 로그인 시트를 띄우는 자리다.
    var onSignIn: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 5) {
                Image("access_wheelchair")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: AccessibilityFeature.wheelchairAccessible.iconSize(height: 16).width, height: 16)
                Text("맞춤 접근성 추천")
                    .font(.notoSans(15, .bold))
            }
            .foregroundStyle(.deepGreen)

            Text(title)
                .font(.heroTitle)
                .foregroundStyle(.textPrimary)
                .lineSpacing(5)
                .accessibilityAddTraits(.isHeader)

            if !accessFeatures.isEmpty {
                // 최대 5개까지 고를 수 있어 한 줄에 들어가지 않는다 — 줄바꿈되는 배치를 쓴다
                //  (`HStack` 이면 칩이 찌그러지거나 카드 밖으로 밀린다).
                FlowLayout {
                    ForEach(accessFeatures, id: \.self) { feature in
                        // 표시는 태그체(`#휠체어접근`), 읽어 주는 것은 원래 이름("휠체어 접근").
                        //  스크린리더가 "샵휠체어접근"으로 읽으면 무슨 말인지 알 수 없다.
                        TagChip(text: "#" + feature.label.replacingOccurrences(of: " ", with: ""))
                            .accessibilityLabel(feature.label)
                    }
                }
            }

            Button {
                if let onSignIn, userName == nil {
                    onSignIn()
                    return
                }
                // TODO: 코스 추천 화면 연결
            } label: {
                HStack(spacing: 4) {
                    Text(userName == nil ? "로그인하기" : "추천 여행 코스 보러가기")
                        .font(.notoSans(16, .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(Color.moduwaGreen))
                .shadow(color: Color(hex: 0x9ACA10).opacity(0.3), radius: 7, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.sheet))
        .shadow(color: .deepGreen.opacity(0.05), radius: 10, y: 2)
    }

    /// 로그인하면 이름을 부르고, 아니면 로그인하면 무엇이 좋아지는지 말한다.
    private var title: String {
        guard let userName, !userName.isEmpty else {
            return "로그인하면\n나에게 맞는 여행을 추천해요"
        }
        return "\(userName) 님,\n\(headline)"
    }

    /// 아래 추천 목록이 **실제로 무엇으로 좁혀졌는지** 말한다.
    ///
    /// ⚠️ 문구는 목록의 필터와 같은 근거(`serverAccessGroup`)를 본다. 고른 항목을 그대로 읽으면
    /// 고령자 친화만 고른 사람에게 "쉬어 갈 곳을 추천해요"라고 해 놓고 목록은 전혀 좁히지
    /// 않은 상태가 된다 — 서버에 그 축이 없기 때문이다(`AccessibilityFeature.serverAccessGroup`).
    /// 문구는 **고른 항목 기준**이다(필터가 무엇을 좁히는지와 분리).
    ///
    /// ⚠️ 고령자는 아직 서버가 좁히지 못한다(`serverAccessGroup == nil`, 어떤 축으로 좁힐지
    /// 기획 확인 중). 그래서 고령자만 고르면 **문구는 시니어 맞춤인데 목록은 일반**이다 —
    /// 알고 넣은 불일치이고, 서버에 고령자 축이 생기면 저절로 맞는다.
    ///
    /// flatPath·barrierFreeRoom 은 사람이 직접 고르는 축이 아니라(`AccessibilityChoiceRow.choices`
    /// 에 없다) 여기 들어오지 않지만, 방어적으로 골라낸 것만 센다.
    private var headline: String {
        let chosen = accessFeatures.filter(AccessibilityChoiceRow.choices.contains)
        switch chosen.count {
        // 해당 없음 — 기획 문구 두 문장. 카드에 몇 줄로 앉는지 실기기에서 확인 중.
        case 0: return "이런 여행은 어떠세요? 추억 남기기 좋은 여행 코스를 추천드려요"
        case 1: return Self.headline(for: chosen[0])
        // 여러 개면 특정 축을 약속하지 않는다 — 어느 축으로 좁혔는지와 무관하게 참이다.
        default: return "나만을 위해 만들어진 추천 여행 코스를 보러 갈까요?"
        }
    }

    /// 항목별 문구(기획 확정본). 사람을 규정하지 않고 **기능 중심**으로 부른다 —
    /// "음성·점자 안내"는 저시력·전맹을 함께 아우르고, 온보딩·내 정보 화면의 항목명과도 결이 같다.
    private static func headline(for feature: AccessibilityFeature) -> String {
        switch feature {
        case .wheelchairAccessible: "휠체어로 이동하기 좋은 코스를 추천드려요"
        case .visuallyImpairedFriendly: "음성·점자 안내가 있는 추천 코스는 어떠세요?"
        case .hearingFriendly: "자막·수어 안내가 있는 추천 코스를 보러 갈까요?"
        case .childFriendly: "아이와 함께하기 좋은 공간들을 추천드려요"
        case .elderlyFriendly: "‘쉼’과 ‘여유’가 있는, 시니어를 위한 여행 코스를 추천드려요"
        // 직접 고르는 축이 아니라 `headline` 에서 걸러져 여기 오지 않는다.
        case .flatPath, .barrierFreeRoom: "무장애 정보가 있는 코스를 추천드려요"
        }
    }
}

#Preview("로그인") {
    HeroCard(
        userName: "바다",
        accessFeatures: [.wheelchairAccessible, .elderlyFriendly, .visuallyImpairedFriendly]
    )
    .padding()
    .background(Color.gradientLime.opacity(0.6))
}

#Preview("로그인 · 무장애 요소 없음") {
    HeroCard(userName: "바다")
        .padding()
        .background(Color.gradientLime.opacity(0.6))
}

#Preview("비로그인") {
    HeroCard(onSignIn: {})
        .padding()
        .background(Color.gradientLime.opacity(0.6))
}
