import SwiftUI

/// 사진이 없는 플랜·일정 카드의 **기본 표지**.
///
/// ⚠️ **사진을 쓰지 않는다**(2026-09-07 결정). 잠깐 경주 사진 두 장을 깔아 뒀는데, 지역이
/// 전국인 앱에서 **제주 플랜에도 경주가 떴다** — 없는 정보를 채우는 것보다 틀린 정보를 주는
/// 쪽이 나쁘다. 지역별 그림을 갖추는 길도 있었지만 지역 수만큼 그림이 필요하고, 새 지역이
/// 생길 때마다 빈자리가 생긴다. 브랜드 무늬는 **어디에도 맞고 아무 곳도 주장하지 않는다.**
///
/// 로고의 스우시를 크게 키워 겹친 무늬다. 바탕이 딥그린인 이유는 **위에 흰 제목이 얹히기**
/// 때문이다 — 흰 글자 대비 8.08:1 이고, 라임 획을 22% 로 눌러 그 대비를 깎지 않는다.
///
/// 그림 파일이 아니라 그리는 이유: 플랜 카드(넓적)와 일정 카드(길쭉)가 비율이 달라 한 장으로는
/// 어느 한쪽이 잘린다. 그려 두면 어느 크기에서도 획 굵기와 간격이 함께 따라간다.
struct BrandCoverPattern: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.deepGreen))

            // 카드 아래쪽을 살짝 눌러 둔다 — 제목·날짜가 앉는 자리다.
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [.black.opacity(0), .black.opacity(0.18)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)))

            // 로고의 스우시를 대각선으로 반복한다. 기준 길이를 긴 변으로 잡아
            //  넓적한 카드와 길쭉한 카드에서 굵기가 같게 보이게 한다.
            let unit = max(size.width, size.height)
            let lineWidth = unit * 0.055

            for step in 0..<4 {
                let t = CGFloat(step)
                let originX = -unit * 0.28 + t * unit * 0.33
                let originY = size.height * 0.16 + t * size.height * 0.22

                var swoosh = Path()
                swoosh.move(to: CGPoint(x: originX, y: originY))
                swoosh.addQuadCurve(
                    to: CGPoint(x: originX + unit * 0.64, y: originY - unit * 0.17),
                    control: CGPoint(x: originX + unit * 0.35, y: originY + unit * 0.19))

                context.stroke(
                    swoosh,
                    with: .color(Color.moduwaGreen.opacity(0.22)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
        // 무늬일 뿐 정보가 아니다 — 카드 본문이 제목·날짜를 이미 읽어 준다.
        .accessibilityHidden(true)
    }
}

#Preview("플랜 카드 비율") {
    VStack(spacing: 16) {
        BrandCoverPattern()
            .frame(width: 320, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("혼자 떠나는 태안 여행")
                        .font(.notoSans(18, .bold))
                    Text("9월 22일 - 9월 25일")
                        .font(.notoSans(14))
                }
                .foregroundStyle(.white)
                .padding(20)
            }

        BrandCoverPattern()
            .frame(width: 160, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    .padding()
}
