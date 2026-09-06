import SwiftUI

/// 사진이 없는 플랜·일정 카드의 **기본 표지** — 회색 한 색으로 채운다.
///
/// ⚠️ **사진을 쓰지 않는다**(2026-09-07 결정). 잠깐 경주 사진 두 장을 깔아 뒀는데, 지역이
/// 전국인 앱에서 **제주 플랜에도 경주가 떴다** — 없는 정보를 비워 두는 것보다 틀린 정보를
/// 주는 쪽이 나쁘다. 지역별 그림은 지역 수만큼 필요하고 새 지역마다 빈자리가 생긴다.
///
/// 브랜드 무늬(라임 스우시)와 라임 단색도 만들어 봤지만 **카드가 화면을 다 가져갔다** —
/// 표지는 제목·날짜를 받치는 자리인데 색이 그 앞에 섰다. 회색은 뒤로 물러난다.
///
/// `cardStroke` 토큰을 쓴다(#E6E6E6). 하드코딩하지 않는 이유는 **고대비에서 `#8C8C8C` 로
/// 짙어지기** 때문이다 — 위에 얹히는 흰 글자에 그만큼 도움이 된다.
struct PlanCoverPlaceholder: View {
    var body: some View {
        Color.cardStroke
            // 색일 뿐 정보가 아니다 — 카드 본문이 제목·날짜를 이미 읽어 준다.
            .accessibilityHidden(true)
    }
}

#Preview("두 카드 비율") {
    VStack(spacing: 16) {
        PlanCoverPlaceholder()
            .frame(width: 320, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        PlanCoverPlaceholder()
            .frame(width: 160, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    .padding()
}
