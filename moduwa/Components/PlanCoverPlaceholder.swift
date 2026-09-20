import SwiftUI

/// 사진이 없는 플랜·일정 카드의 **기본 표지**.
///
/// ## 지역이 있으면 그 지역 사진, 없으면 회색
///
/// 이 표지는 세 판을 거쳤다. 남겨 두는 이유는 다시 돌아가지 않기 위해서다:
///
/// 1. **경주 사진 한 장을 모든 플랜에** — 제주 플랜에도 경주가 떴다. 없는 정보를 비워 두는
///    것보다 **틀린 정보를 주는 쪽이 나쁘다**(2026-09-07 에 뺐다).
/// 2. **브랜드 무늬 · 라임 단색** — 카드가 화면을 다 가져갔다. 표지는 제목·날짜를 받치는
///    자리인데 색이 그 앞에 섰다.
/// 3. **회색 한 색** — 뒤로는 물러났지만 카드가 밋밋하고, 흰 제목의 명암비가 2.14:1 까지
///    떨어졌다(2026-09-07 실측).
///
/// 이제 **지역마다 제 사진이 있다**(디자이너 에셋, 2026-09-20). 1번의 걱정이 사라졌으므로
/// 사진으로 돌아간다 — 다만 **지역을 아는 플랜에만**이다. 지역을 고르지 않은 플랜은 여전히
/// 회색이다(그 자리에 아무 사진이나 놓으면 1번으로 되돌아간다).
struct PlanCoverPlaceholder: View {
    /// 플랜의 지역. `nil` 이면 회색으로 남는다.
    var region: TravelRegion?
    /// 세로로 선 카드(일정 탭)인지. 비율이 달라 에셋이 두 벌이다.
    var tall = false

    var body: some View {
        if let region {
            Image(region.coverImageName(tall: tall))
                .resizable()
                .scaledToFill()
                // 사진은 분위기일 뿐 정보가 아니다 — 카드 본문이 제목·날짜를 이미 읽어 준다.
                .accessibilityHidden(true)
        } else {
            // `cardStroke` 토큰을 쓴다(#E6E6E6). 하드코딩하지 않는 이유는 **고대비에서
            //  `#8C8C8C` 로 짙어지기** 때문이다 — 위에 얹히는 흰 글자에 그만큼 도움이 된다.
            Color.cardStroke
                .accessibilityHidden(true)
        }
    }
}

#Preview("두 카드 비율") {
    VStack(spacing: 16) {
        PlanCoverPlaceholder(region: .gyeongju)
            .frame(width: 320, height: 243)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        PlanCoverPlaceholder(region: .jeju, tall: true)
            .frame(width: 320, height: 378)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        PlanCoverPlaceholder()
            .frame(width: 320, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    .padding()
}
