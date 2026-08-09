import Foundation

// 플랜 목 데이터 — 내용은 피그마 목록(391:232)·상세(509:340, 519:775) 시안 그대로.
//
// 날짜만 시안을 그대로 쓰지 않는다. 시안의 진행 중 플랜은 "7월 26일 - 7월 27일"인데
// 지금 기준으로는 이미 지난 날짜라, 그대로 넣으면 `isPast()`가 지난 여행으로 판정해
// 정작 확인해야 할 진행 중 카드가 안 나온다. 다가오는 플랜만 오늘 기준 상대 날짜로 잡는다.
extension MockData {
    static let plans: [Plan] = [upcomingGyeongju, pastBusan, pastMemory]

    /// 진행 중 플랜. 상세·편집 시안이 전부 이 플랜을 그린다.
    static let upcomingGyeongju = Plan(
        title: "동궁과 월지 폼 미쳐따",
        startDate: daysFromToday(3),
        endDate: daysFromToday(4),
        region: .gyeongju,
        // 새 플랜 플로우 1/6 선택시(391:96) 상태 — 20대·30대 / 친구와 / 뚜벅이
        party: TravelParty(
            ageGroups: [.twenties, .thirties],
            companions: [.friends],
            mobilities: [.walking]
        ),
        days: [
            PlanDay(
                date: daysFromToday(3),
                items: [
                    .stop(PlanStop(place: hwangridanGil)),
                    .stop(PlanStop(
                        place: poseokjeong
                    )),
                    .stop(PlanStop(
                        place: hanaroMart
                    )),
                    .stop(PlanStop(
                        place: najeongBeach
                    )),
                ]
            ),
            PlanDay(
                date: daysFromToday(4),
                items: [
                    .stop(PlanStop(place: donggungAndWolji)),
                    .memo(PlanMemo(text: "체크아웃 11시. 월지 야경은 해 진 뒤가 예쁘다고 함")),
                ]
            ),
        ]
    )

    static let pastBusan = Plan(
        title: "떠나자!! 부산으로!!",
        startDate: date(2026, 4, 3),
        endDate: date(2026, 4, 6),
        region: .busan,
        party: TravelParty(ageGroups: [.twenties], companions: [.friends], mobilities: [.walking]),
        days: [
            PlanDay(
                date: date(2026, 4, 3),
                items: [
                    .stop(PlanStop(place: gamcheonVillage)),
                    .stop(PlanStop(
                        place: haeundae
                    )),
                ]
            )
        ]
    )

    static let pastMemory = Plan(
        title: "추억여행",
        startDate: date(2025, 12, 17),
        endDate: date(2025, 12, 20)
    )
}

// MARK: - 장소

private extension MockData {
    /// 좌표는 지도 핀·거리순 정렬을 붙여보기 위한 대략값이다 — 실제 관광공사 좌표가 아니다.
    static var hwangridanGil: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-1",
            name: "황리단길",
            categoryLabel: "관광명소",
            region: "경주시내",
            category: .attraction,
            latitude: 35.8367,
            longitude: 129.2103
        )
    }

    static var poseokjeong: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-2",
            name: "포석정",
            categoryLabel: "관광명소",
            region: "경북 경주시",
            category: .attraction,
            latitude: 35.8172,
            longitude: 129.2044
        )
    }

    /// 시안에선 리뷰 버튼이 꺼져 있지만 나만의 장소가 아니라 시안 쪽 실수다(2026-08-02 확인).
    /// 규칙대로 리뷰 버튼이 뜬다. "쇼핑"은 `PlaceCategory` 4종에 없어 category는 nil.
    static var hanaroMart: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-3",
            name: "하나로 마트",
            categoryLabel: "쇼핑",
            region: "경주시내",
            category: nil,
            latitude: 35.8420,
            longitude: 129.2120
        )
    }

    /// 목록에 없어 직접 추가한 "나만의 장소" — contentID가 nil이라 라임 뱃지 + 리뷰 버튼 없음.
    static var najeongBeach: PlanPlace {
        PlanPlace(
            contentID: nil,
            name: "나정 고운모래 해변",
            categoryLabel: "숙소",
            region: nil,
            category: .stay,
            latitude: 35.7278,
            longitude: 129.4836
        )
    }

    static var donggungAndWolji: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-5",
            name: "동궁과 월지",
            categoryLabel: "관광명소",
            region: "경주시내",
            category: .attraction,
            latitude: 35.8348,
            longitude: 129.2265
        )
    }

    static var gamcheonVillage: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-6",
            name: "감천문화마을",
            categoryLabel: "관광명소",
            region: "부산 사하구",
            category: .attraction,
            latitude: 35.0975,
            longitude: 129.0107
        )
    }

    static var haeundae: PlanPlace {
        PlanPlace(
            contentID: "mock-plan-place-7",
            name: "해운대해수욕장",
            categoryLabel: "관광명소",
            region: "부산 해운대구",
            category: .attraction,
            latitude: 35.1587,
            longitude: 129.1604
        )
    }
}

// MARK: - 날짜

private extension MockData {
    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static func daysFromToday(_ offset: Int) -> Date {
        let today = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }
}
