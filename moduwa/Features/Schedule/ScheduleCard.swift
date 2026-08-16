import SwiftUI

/// 일정 탭 카드 — 시안 "03. 일정"(532:241)의 `카드`(631:146).
///
/// 321×378, 풀블리드 사진 위에 하단 204pt 스크림을 깔고 제목·날짜·DAY별 동선을 얹는다.
/// 플랜 탭 카드(`PlanListView`)와 데이터는 같지만 **그날 무엇을 하는지까지 보여 준다** —
/// 일정 탭은 짜 놓은 것을 훑어보는 화면이라 카드만 보고도 내용이 잡혀야 한다.
/// ⋮ 메뉴는 여기 없다 — 호출부가 링크의 **형제**로 얹는다(`PlanCard`와 같은 이유).
/// 카드 안에 넣으면 ⋮ 를 누른 손가락이 상세로도 들어간다.
struct ScheduleCard: View {
    let plan: Plan

    /// 시안 카드 규격(631:146 / 631:150).
    private static let height: CGFloat = 378
    /// 흐림·스크림이 걸리는 아래쪽 띠. 카드 높이의 46% 지점부터 시작한다.
    private static let blurBandHeight: CGFloat = 204
    private static var blurBandStart: CGFloat { (height - blurBandHeight) / height }
    /// 시안 `BACKGROUND_BLUR` 의 최대 반경. 위(0)에서 아래(60)로 커지는 PROGRESSIVE 다.
    private static let blurRadius: CGFloat = 60
    /// 시안의 DAY 줄은 세 개다. 그보다 긴 여행은 마지막 줄을 "…"로 접는다 —
    /// 카드 높이가 고정이라 줄을 늘리면 아래가 잘린다.
    private static let visibleDayCount = 3


    /// 장소가 하나도 없는 날은 줄을 그리지 않는다. **번호는 원래 자리를 지킨다** —
    /// 메모만 있는 날 때문에 DAY 2 가 사라지고 DAY 3 이 둘째 줄로 올라오면 상세와 어긋난다.
    private var dayLines: [(number: Int, places: [String])] {
        plan.daySummaries.enumerated()
            .filter { !$0.element.placeNames.isEmpty }
            .map { (number: $0.offset + 1, places: $0.element.placeNames) }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            scrim
            content
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        // 시안 카드의 그림자 — 딥그린 5%, 반경 10, y2 (앱의 다른 카드와 같은 값)
        .shadow(color: Color.deepGreen.opacity(0.05), radius: 10, y: 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: 배경

    /// 사진 위에 **흐린 사본**을 겹친다 — 시안의 `BACKGROUND_BLUR`(PROGRESSIVE, 0→60)다.
    ///
    /// SwiftUI 에는 반경이 위치에 따라 변하는 흐림이 없다. 그래서 한 가지 반경으로 흐린 사본을
    /// 만들고 **마스크로 그 사본의 농도를 아래로 갈수록 올린다** — 반경이 커지는 대신 흐린 그림이
    /// 점점 진하게 겹쳐지므로 눈에는 같은 방향으로 읽힌다.
    ///
    /// 사본을 `AsyncImage` 의 content 안에서 만드는 이유는 **같은 이미지를 두 번 받지 않기**
    /// 위해서다. 밖에서 `AsyncImage` 를 하나 더 두면 네트워크 요청이 두 번 나간다.
    private var background: some View {
        Color.photoPlaceholder
            .overlay {
                if let imageURL = plan.cardImageURL {
                    AsyncImage(url: imageURL) { image in
                        ZStack {
                            image.resizable().scaledToFill()
                            image.resizable().scaledToFill()
                                // opaque: true — 아니면 흐린 사본의 가장자리가 투명해져
                                // 카드 테두리에 밝은 띠가 생긴다.
                                .blur(radius: Self.blurRadius, opaque: true)
                                .mask(blurMask)
                        }
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// 흐림 띠의 농도. 위쪽(사진 그대로)에서 아래쪽(완전히 흐림)으로 넘어간다.
    private var blurMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: Self.blurBandStart),
                .init(color: .black.opacity(0.55),
                      location: Self.blurBandStart + (1 - Self.blurBandStart) * 0.45),
                .init(color: .black, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 흐림 위에 얹는 스크림. 시안 값 그대로다 — 그라디언트 자체의 불투명도가 0.5 라
    /// 각 정지점의 알파에 0.5 를 곱한 값이 실제 농도다(검정 0.5→0.25, 검정 1.0→0.5).
    /// 예전에 0.35/0.75 로 그려 시안보다 한참 어두웠다.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.25), location: 0.173),
                .init(color: .black.opacity(0.5), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Self.blurBandHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: 본문

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(plan.title)
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)
                .lineLimit(1)

            Text(plan.dottedDateRangeText)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.4)
                .padding(.top, 6)

            if !dayLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(dayLines.prefix(Self.visibleDayCount), id: \.number) { line in
                        dayRow(number: line.number, places: line.places)
                    }
                    if dayLines.count > Self.visibleDayCount {
                        Text("…")
                            .font(.notoSans(14, .regular, relativeTo: .subheadline))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 14)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 27)
        .padding(.bottom, 19)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "DAY 1   황리단길 - 포석정 - 나정고운모래해변"
    ///
    /// 장소가 많으면 폭이 넘친다. 시안은 그 경우를 숨긴 노드(`...`)로 지시해 뒀다 —
    /// 한 줄로 자르고 꼬리표를 붙이는 것은 `lineLimit(1)` + `truncationMode(.tail)` 이 해 준다.
    private func dayRow(number: Int, places: [String]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("DAY \(number)")
                .font(.notoSans(14, .medium, relativeTo: .subheadline))
                // 번호 폭을 고정해 장소 이름의 시작점이 줄마다 어긋나지 않게 한다.
                .frame(width: 36, alignment: .leading)

            placesText(places)
                .tracking(-0.4)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 시안은 장소 이름(14 Regular)과 사이의 `-`(**16** Regular)의 크기를 다르게 준다 —
    /// 이름보다 구분자를 살짝 키워 덩어리가 끊겨 읽히게 한 것이다. 한 문자열로 이으면
    /// 그 차이가 사라지므로 조각을 이어 붙인다.
    private func placesText(_ places: [String]) -> Text {
        places.enumerated().reduce(Text("")) { acc, item in
            let name = Text(item.element)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
            guard item.offset > 0 else { return acc + name }
            let separator = Text(" - ")
                .font(.notoSans(16, .regular, relativeTo: .subheadline))
            return acc + separator + name
        }
    }

    private var accessibilitySummary: String {
        var parts = [plan.title, plan.dottedDateRangeText]
        for line in dayLines.prefix(Self.visibleDayCount) {
            parts.append("DAY \(line.number) \(line.places.joined(separator: ", "))")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("일정 카드") {
    ScheduleCard(plan: MockData.upcomingGyeongju.withSummaries)
        .padding(.horizontal, 36)
        .background(Color.appBackground)
}

private extension Plan {
    /// 프리뷰용 — 목 데이터는 목록 응답을 거치지 않아 요약이 비어 있다.
    var withSummaries: Plan {
        var copy = self
        copy.daySummaries = days.map {
            PlanDaySummary(date: $0.date, placeNames: $0.stops.map(\.place.name))
        }
        return copy
    }
}
