import SwiftUI

/// 표지 사진 아래쪽을 흐리게 깔아 그 위 흰 글자가 읽히게 한다 —
/// 시안의 `BACKGROUND_BLUR (PROGRESSIVE, 0 → 60)`.
///
/// **일정 탭 카드(`ScheduleCard`)와 플랜 목록의 다가오는 여행 카드(`UpcomingPlanCard`)가
/// 같은 것을 쓴다.** 두 곳에 따로 적었더니 한쪽만 고쳐질 자리가 생겨 한 곳으로 모았다
/// (2026-09-20).
///
/// ## 왜 진짜 progressive 가 아닌가
///
/// SwiftUI 에는 **반경이 위치에 따라 변하는 흐림이 없다.** 반경을 실제로 0→60 으로 올리려면
/// 반경이 다른 사본을 여러 장 겹쳐야 하는데, 표지가 `AsyncImage` 라 장수만큼 비용이 붙는다
/// (목록에서 카드가 여러 장 스크롤된다).
///
/// 그래서 **한 가지 반경으로 흐린 사본 한 장**을 만들고 마스크로 그 사본의 농도를 아래로
/// 갈수록 올린다. 반경이 커지는 대신 흐린 그림이 점점 진하게 겹쳐지므로 눈에는 같은 방향으로
/// 읽힌다. 시안과 다른 점을 알고 택한 것이다.
struct CardCoverBlur<Cover: View>: View {
    /// 표지 한 장을 그리는 클로저. **`Image` 가 아니라 뷰를 받는다** — 사진이 없을 때의 기본
    /// 표지가 `PlanCoverPlaceholder`(색)라 둘의 타입이 갈렸다.
    ///
    /// ⚠️ **이 클로저는 두 번 호출된다**(원본 한 장 + 흐린 사본 한 장). 그래서 `AsyncImage`
    /// 자체를 여기 넘기면 **같은 사진을 두 번 받는다.** 부르는 쪽에서 `AsyncImage` 의 content
    /// 안에서 이 뷰를 만들어, 이미 받아 온 `Image` 를 넘겨야 한다.
    @ViewBuilder let cover: () -> Cover

    /// 카드 전체 높이. 흐림 띠가 어디서 시작하는지를 이 값과 `bandHeight` 로 계산한다.
    let cardHeight: CGFloat
    /// 흐림 띠의 높이.
    let bandHeight: CGFloat

    /// 시안 `End blur` 값 그대로.
    private static var blurRadius: CGFloat { 60 }

    private var bandStart: CGFloat {
        guard cardHeight > 0 else { return 0 }
        return max(0, (cardHeight - bandHeight) / cardHeight)
    }

    var body: some View {
        ZStack {
            cover()
            cover()
                // ⚠️ **`opaque: true` 여야 한다.** 기본값(false)이면 흐린 사본의 가장자리가
                //  투명해져 카드 테두리에 밝은 띠가 생긴다.
                .blur(radius: Self.blurRadius, opaque: true)
                .mask(mask)
        }
    }

    /// 흐림의 농도. 위(사진 그대로)에서 아래(완전히 흐림)로 넘어간다.
    /// 가운데 정지점이 없으면 띠가 시작하는 선이 눈에 띈다 — 시안의 `#000000 50%` 가 그 자리다.
    private var mask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: bandStart),
                .init(color: .black.opacity(0.55),
                      location: bandStart + (1 - bandStart) * 0.45),
                .init(color: .black, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// 흐림 위에 얹는 어둡게 덮는 층(시안 `Linear Gradient`).
///
/// 흐림만으로는 밝은 사진에서 흰 글자가 뜨지 않는다 — 흐려도 밝기는 그대로이기 때문이다.
///
/// ⚠️ 시안 그라디언트 자체의 불투명도가 **0.5** 라, 각 정지점의 알파에 0.5 를 곱한 값이 실제
/// 농도다(검정 0.5 → 0.25, 검정 1.0 → 0.5). 예전에 0.35/0.75 로 그려 시안보다 한참 어두웠다.
struct CardCoverScrim: View {
    let bandHeight: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.25), location: 0.173),
                .init(color: .black.opacity(0.5), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: bandHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
