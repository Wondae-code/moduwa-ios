import SwiftUI

/// 사진이 없는 플랜·일정 카드의 **기본 표지** — 옅은 회색 한 색으로 채운다.
///
/// ⚠️ **사진을 쓰지 않는다**(2026-09-07 결정). 잠깐 경주 사진 두 장을 깔아 뒀는데, 지역이
/// 전국인 앱에서 **제주 플랜에도 경주가 떴다** — 없는 정보를 비워 두는 것보다 틀린 정보를
/// 주는 쪽이 나쁘다. 지역별 그림은 지역 수만큼 필요하고 새 지역마다 빈자리가 생긴다.
///
/// 브랜드 무늬(라임 스우시)와 라임 단색도 만들어 봤지만 **카드가 화면을 다 가져갔다** —
/// 표지는 제목·날짜를 받치는 자리인데 색이 그 앞에 섰다. 회색은 뒤로 물러난다.
///
/// ⚠️ **이 표지 위의 글자는 딥그린이어야 한다.** 옅은 회색 위에서 흰 글자는 1.1:1 로
/// 보이지 않는다. `textPrimary`(#0B2A1C)면 **14:1** 이다. 그래서 호출부는 기본 표지일 때
/// **사진용 검은 스크림을 걷고 글자를 딥그린으로 바꾼다** — 스크림은 밝은 회색을 어둡게
/// 만들어 딥그린 글자의 대비를 오히려 깎는다.
struct PlanCoverPlaceholder: View {
    /// 2026-09-07 지정값. 디자인 토큰의 `cardStroke`(#E6E6E6)와 `photoPlaceholder`(#F2F2F2)
    /// 사이라 둘 중 하나로 대신하지 않는다 — 카드 표지 전용 값이다.
    private static let fill = Color(hex: 0xEBEBEB)

    var body: some View {
        Self.fill
            // 색일 뿐 정보가 아니다 — 카드 본문이 제목·날짜를 이미 읽어 준다.
            .accessibilityHidden(true)
    }
}

#Preview("두 카드 비율") {
    VStack(spacing: 16) {
        PlanCoverPlaceholder()
            .frame(width: 320, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("혼자 떠나는 태안 여행").font(.notoSans(18, .bold))
                    Text("9월 22일 - 9월 25일").font(.notoSans(14))
                }
                .foregroundStyle(Color.textPrimary)
                .padding(20)
            }

        PlanCoverPlaceholder()
            .frame(width: 160, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    .padding()
}
