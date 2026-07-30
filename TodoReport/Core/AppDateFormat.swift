import Foundation

/// 화면 표시용 날짜 문자열. Notion/API/로그 전송 포맷에는 사용하지 않는다.
enum AppDateFormat {
    private static var isKorean: Bool {
        Locale.autoupdatingCurrent.language.languageCode?.identifier == "ko"
    }

    // MARK: - Cached formatters (ko)

    private static let koMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()

    private static let koMonthDayWeekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (EEE)"
        return f
    }()

    private static let koYearMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "y년 M월 d일"
        return f
    }()

    private static let koYearMonthDayWeekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "y년 M월 d일 (EEE)"
        return f
    }()

    private static let koInterval: DateIntervalFormatter = {
        let f = DateIntervalFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    // MARK: - Cached formatters (non-ko — 기존 템플릿 유지)

    private static let nonKoTodoNavigation: DateFormatter = makeTemplateFormatter("MMMdE")
    private static let nonKoReportDailyHeader: DateFormatter = makeTemplateFormatter("yMMMdE")
    private static let nonKoReportShort: DateFormatter = makeTemplateFormatter("yMd")
    private static let nonKoReviewTimeline: DateFormatter = makeTemplateFormatter("MdE")
    private static let nonKoExpiration: DateFormatter = makeTemplateFormatter("yMMMd")

    private static func makeTemplateFormatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = DateFormatter.dateFormat(
            fromTemplate: template,
            options: 0,
            locale: .autoupdatingCurrent
        )
        return f
    }

    // MARK: - Public API

    /// 투두 날짜행 base. ko: `7월 30일` / `7월 30일 (목)`. 그 외: 기존 `MMMdE`.
    /// 오늘·어제·내일 래퍼에는 `includeWeekday: false`.
    static func todoNavigationBase(_ date: Date, includeWeekday: Bool) -> String {
        if isKorean {
            return includeWeekday
                ? koMonthDayWeekday.string(from: date)
                : koMonthDay.string(from: date)
        }
        return nonKoTodoNavigation.string(from: date)
    }

    /// 리포트 일간 헤더. ko: `2026년 7월 30일 (목)`. 그 외: 기존 `yMMMdE`.
    static func reportDailyHeader(_ date: Date) -> String {
        if isKorean {
            return koYearMonthDayWeekday.string(from: date)
        }
        return nonKoReportDailyHeader.string(from: date)
    }

    /// 리포트 단기 범위. ko: `DateIntervalFormatter.long`(주간 기간과 동일). 그 외: 기존 `yMd ~ yMd`.
    static func reportShortRange(from start: Date, to end: Date) -> String {
        if isKorean {
            return koInterval.string(from: start, to: end)
        }
        return "\(nonKoReportShort.string(from: start)) ~ \(nonKoReportShort.string(from: end))"
    }

    /// 리뷰 타임라인 행. ko: `7월 30일 (목)`. 그 외: 기존 `MdE`.
    static func reviewTimeline(_ date: Date) -> String {
        if isKorean {
            return koMonthDayWeekday.string(from: date)
        }
        return nonKoReviewTimeline.string(from: date)
    }

    /// Pro 만료일. ko: `2026년 7월 30일`. 그 외: 기존 `yMMMd`.
    static func expirationDate(_ date: Date) -> String {
        if isKorean {
            return koYearMonthDay.string(from: date)
        }
        return nonKoExpiration.string(from: date)
    }
}
