import SwiftUI

/// 플랜 상세 — Figma "03-1. 플랜 상세 - 지도 & Day별 view"(509:340)
///
/// 지도가 본문이고 Day별 일정이 그 위로 올라오는 바텀시트다.
/// 시트 상단 핸들을 누르면 지도를 접어 "Day별 view"(519:775) 상태가 된다.
struct PlanDetailView: View {
    let plan: Plan

    @Environment(\.dismiss) private var dismiss
    @State private var showsMap = true
    /// 카카오맵 엔진은 레이아웃이 잡힌 뒤에 켜야 한다 — 미리 켜면 렌더링이 멈춘다.
    @State private var mapDrawn = false

    /// 시안은 지도에 DAY 1의 핀만 찍는다. 여러 날을 한 번에 그리면 번호가 중복돼 읽기 어렵다.
    private var mappedStops: [PlanStop] {
        plan.days.first?.stops ?? []
    }

    private var hasMap: Bool {
        mappedStops.contains { $0.place.latitude != nil && $0.place.longitude != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        titleBlock

                        if showsMap, hasMap {
                            // bottomInset은 시안 기준 지도 331 중 시트에 덮이는 137 — 카메라 맞춤에만 쓰인다.
                            PlanRouteMap(stops: mappedStops, bottomInset: 137, draw: $mapDrawn)
                                .frame(height: 331)
                                .onAppear { mapDrawn = true }
                                .onDisappear { mapDrawn = false }
                        }

                        Spacer(minLength: 0)
                    }

                    sheet
                        // 시안 비율 — 본문 662 중 시트가 365(≈55%)를 차지한다.
                        .frame(height: showsMap && hasMap ? geo.size.height * 0.55 : geo.size.height)
                }
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }

            Text("여행 상세")
                .font(.notoSans(18, .bold, relativeTo: .headline))
                .tracking(-0.4)
                .padding(.leading, 14)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                // 검색·편집은 아직 목적지가 없다 — 시안 자리만 잡아둔다.
                // 연필은 장소 상세와 같은 글리프라(좌표만 +2.7 평행이동) 기존 에셋을 그대로 쓴다.
                headerIcon("plan_search", size: 25) {}
                // 시안은 26 박스 안에 21.4짜리 연필을 담지만 detail_pencil은 여백 없이 뽑혀 있다 —
                // 26으로 그리면 아트워크가 21.5% 커져 획이 두꺼워지므로 원래 크기로 그린다.
                headerIcon("detail_pencil", size: 21.41, slot: 26) {}
                // 지도는 접힌 지도 위에 핀이 얹힌 2색 아이콘이라 틴트를 입히면 핀이 묻힌다.
                headerIcon("plan_map", size: 26, isTemplate: false) { toggleMap() }
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(Color.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.cardStroke)
                .frame(height: 1)
        }
    }

    /// `slot`은 시안의 아이콘 박스 크기, `size`는 그 안에 실제로 그려지는 아트워크 크기다.
    /// 에셋마다 여백 포함 여부가 달라 둘을 분리해 둔다.
    private func headerIcon(
        _ name: String,
        size: CGFloat,
        slot: CGFloat? = nil,
        isTemplate: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(name)
                .renderingMode(isTemplate ? .template : .original)
                .resizable()
                .frame(width: size, height: size)
                .frame(width: slot ?? size, height: slot ?? size)
        }
    }

    private func toggleMap() {
        guard hasMap else { return }
        withAnimation(.snappy(duration: 0.25)) { showsMap.toggle() }
    }

    // MARK: 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(plan.title)
                .font(.notoSans(20, .bold, relativeTo: .title3))
                .tracking(-0.4)

            Text(plan.dateRangeText)
                .font(.notoSans(16, .regular, relativeTo: .body))
                .tracking(-0.4)
        }
        .foregroundStyle(Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
        .padding(.top, 24)
        .padding(.bottom, 25)
    }

    // MARK: 바텀시트

    private var sheet: some View {
        VStack(spacing: 0) {
            handle

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(plan.days.enumerated()), id: \.element.id) { index, day in
                        dayHeader(number: index + 1, day: day)
                        dayTimeline(day)
                    }

                    bottomActions
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: Color.deepGreen.opacity(0.08), radius: 10, y: -2)
    }

    private var handle: some View {
        Button(action: toggleMap) {
            Image(systemName: showsMap && hasMap ? "chevron.compact.up" : "chevron.compact.down")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.iconGray)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .contentShape(.rect)
        }
        .disabled(!hasMap)
        .opacity(hasMap ? 1 : 0)
    }

    // MARK: Day

    private func dayHeader(number: Int, day: PlanDay) -> some View {
        HStack(spacing: 0) {
            Text("DAY \(number) · \(day.headerText)")
                .font(.notoSans(16, .bold, relativeTo: .headline))

            Spacer(minLength: 0)

            Button {
                // 일정 편집(519:987)은 아직 미구현
            } label: {
                Text("편집")
                    .font(.notoSans(16, .medium, relativeTo: .headline))
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    /// 번호 뱃지 뒤로 점선이 세로로 지난다(시안 Line 3). 뱃지 중심에 맞춰 깔아둔다.
    private func dayTimeline(_ day: PlanDay) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                switch item {
                case .stop(let stop):
                    if let leg = stop.travelFromPrevious {
                        PlanLegRow(leg: leg)
                    }
                    PlanStopRow(number: day.stopNumber(at: index) ?? 0, stop: stop)
                case .memo(let memo):
                    PlanMemoRow(memo: memo)
                }
            }
        }
        .background(alignment: .topLeading) {
            DashedVerticalLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color.cardStroke)
                .frame(width: 1)
                .padding(.leading, 11.5)
        }
        .padding(.bottom, 16)
    }

    // MARK: 하단 액션

    private var bottomActions: some View {
        HStack(spacing: 11) {
            bottomButton("장소 추가")
            bottomButton("메모 추가")
        }
        .padding(.top, 14)
    }

    private func bottomButton(_ title: String) -> some View {
        Button {
        } label: {
            Text(title)
                .font(.notoSans(16, .medium, relativeTo: .headline))
                .tracking(-0.064)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.cardStroke, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 장소 행

private struct PlanStopRow: View {
    let number: Int
    let stop: PlanStop

    private var place: PlanPlace { stop.place }

    var body: some View {
        HStack(spacing: 14) {
            PlanNumberBadge(number: number, isCustom: place.isCustom)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.notoSans(16, .medium, relativeTo: .headline))
                        .tracking(-0.064)
                        .foregroundStyle(Color.textPrimary)

                    Text(place.subtitle)
                        .font(.notoSans(14, .regular, relativeTo: .subheadline))
                        .tracking(-0.056)
                        .foregroundStyle(Color.textSecondary)
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                if place.showsReviewAction {
                    Rectangle()
                        .fill(Color.cardStroke)
                        .frame(width: 1, height: 56)

                    Button {
                        // 리뷰 상세 연결은 contentID ↔ 리뷰 매핑이 필요해 아직 미구현
                    } label: {
                        VStack(spacing: 3) {
                            Image("star")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 15, height: 14.27)
                            Text("리뷰")
                                .font(.notoSans(11, .regular, relativeTo: .caption))
                                .tracking(-0.044)
                        }
                        .foregroundStyle(Color.deepGreen)
                        .frame(width: 61)
                    }
                }
            }
            .padding(.leading, 16)
            .frame(height: 57)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardStroke, lineWidth: 1)
            }
        }
    }
}

// MARK: - 이동 거리

private struct PlanLegRow: View {
    let leg: TravelLeg

    var body: some View {
        Text(leg.distanceText)
            .font(.notoSans(12, .medium, relativeTo: .caption))
            .foregroundStyle(Color.iconGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 39)
    }
}

// MARK: - 메모

/// 시안에 메모 렌더가 없어 장소 카드 규격(라운드·좌측 정렬)만 따라간 임시 형태다.
private struct PlanMemoRow: View {
    let memo: PlanMemo

    var body: some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: 24, height: 24)

            Text(memo.text)
                .font(.notoSans(14, .regular, relativeTo: .subheadline))
                .tracking(-0.056)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.photoPlaceholder, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 점선

private struct DashedVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(plan: MockData.upcomingGyeongju)
    }
}
