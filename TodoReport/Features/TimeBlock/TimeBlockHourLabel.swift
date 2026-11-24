import SwiftUI

/// 왼쪽 시각 표시. 숫자는 크게, 오전/오후는 작게. 24시간제 기기는 0~23만 표시.
struct TimeBlockHourLabel: View {
    let hour: Int

    private static let uses12HourClock: Bool = {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return format.contains("a")
    }()

    private var displayHour: Int {
        guard Self.uses12HourClock else { return hour % 24 }
        let value = hour % 12
        return value == 0 ? 12 : value
    }

    private var periodSymbol: String? {
        guard Self.uses12HourClock else { return nil }
        let calendar = Calendar.current
        return (hour % 24) < 12 ? calendar.amSymbol : calendar.pmSymbol
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(displayHour, format: .number)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.secondaryLabel))
                .monospacedDigit()
            if let periodSymbol {
                Text(periodSymbol)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}
