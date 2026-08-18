import Foundation

/// "방금 · 3분 전 · 5시간 전 · 어제 · 2026.08.16"
///
/// 피드에서 작성 시각은 **얼마나 최근인지**가 먼저다 — 오늘 쓴 글에 날짜를 찍으면 새 글인지
/// 알 수 없다. 하루가 넘으면 반대로 정확한 날짜가 쓸모 있어져 점 표기로 바뀐다.
///
/// `RelativeDateTimeFormatter` 를 쓰지 않는 이유: 로케일에 따라 "3분 전"이 "3 minutes ago"
/// 로 바뀌는데 이 앱은 한국어 전용이고, 포매터를 static 으로 들면 Sendable 예외를 달아야 한다
/// (`PlanDateText` 와 같은 판단).
enum RelativeTimeText {
    static func string(from date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)

        // 시계가 어긋나 미래 시각이 오는 경우도 있다 — 음수를 "…후"로 보여 줄 이유가 없다.
        guard seconds >= 0 else { return "방금" }
        if seconds < 60 { return "방금" }
        if seconds < 3600 { return "\(Int(seconds / 60))분 전" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))시간 전" }

        // 하루를 넘기면 "며칠 전"보다 날짜가 낫다 — 다만 어제까지는 말이 더 자연스럽다.
        if calendar.isDateInYesterday(date) { return "어제" }
        return PlanDateText.dotted(date, calendar: calendar)
    }
}
