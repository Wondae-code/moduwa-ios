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
    /// 흐림·스크림이 걸리는 범위 — **카드 전체**다(시안 `Y start 0% → Y end 100%`).
    ///
    /// 한동안 아래 204 만 덮었다(카드의 46% 지점부터). 그랬더니 **제목이 띠 바로 위에 걸려**
    /// 밝은 사진에서 거의 읽히지 않았다(2026-09-20, 전주 표지에서 실측 — 하늘 위 흰 글자).
    /// 위는 어차피 흐림 0·스크림 0 이라 사진이 그대로 보인다 — 넓혀도 잃는 것이 없다.
    private static let blurBandHeight: CGFloat = height
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

    /// 사진 위에 흐린 사본을 겹친다 — 시안의 `BACKGROUND_BLUR`(PROGRESSIVE, 0→60).
    /// 왜 진짜 progressive 가 아닌지는 `CardCoverBlur` 에 적혀 있다.
    ///
    /// ⚠️ 사본을 `AsyncImage` 의 **content 안에서** 만든다 — 밖에서 `AsyncImage` 를 하나 더
    /// 두면 **같은 사진을 두 번 받는다**(`CardCoverBlur` 가 표지 클로저를 두 번 부른다).
    private var background: some View {
        Color.photoPlaceholder
            .overlay {
                // 무엇을 표지로 쓸지는 `Plan.coverSource` 가 정한다 — 플랜 탭과 같은 규칙이다.
                switch plan.coverSource {
                case .photo(let url):
                    AsyncImage(url: url) { image in
                        layered { image.resizable().scaledToFill() }
                    } placeholder: {
                        Color.photoPlaceholder
                    }
                case .region(let region):
                    layered { PlanCoverPlaceholder(region: region, tall: true) }
                case .blank:
                    // 한 색이라 흐릴 것이 없다 — 사본을 겹치지 않는다.
                    PlanCoverPlaceholder()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// 표지와 흐린 사본을 겹친 한 장. 모양과 함정은 `CardCoverBlur` 가 안다 —
    /// 플랜 목록의 다가오는 여행 카드가 같은 것을 쓴다.
    /// ⚠️ `@escaping` 이다 — `CardCoverBlur` 가 이 클로저를 **저장**했다가 두 번 그린다.
    private func layered<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        CardCoverBlur(cover: content, cardHeight: Self.height, bandHeight: Self.blurBandHeight)
    }

    private var scrim: some View { CardCoverScrim(bandHeight: Self.blurBandHeight) }

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
                // ⚠️ **폭을 고정하면 안 된다.** 36 으로 묶어 뒀더니 "DAY 1" 이 그 안에
                //  안 들어가 **"DAY" / "1" 두 줄로 접혔다**(2026-09-20 지적, 시안은 한 줄이다).
                //  글자 크기를 키우면 더 심해진다.
                //
                //  대신 **줄바꿈을 막고 최소 폭만** 준다 — 접히지 않으면서, 한 자리 숫자끼리는
                //  36 에 맞춰 장소 이름의 시작점이 줄마다 나란히 선다. 열흘 넘는 여행에서
                //  "DAY 10" 이 조금 넓어지는 것은 접히는 것보다 낫다.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 36, alignment: .leading)

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
