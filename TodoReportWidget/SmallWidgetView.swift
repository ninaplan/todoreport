import SwiftUI
import WidgetKit

// MARK: - Small Widget (systemSmall)
// 오늘 완료율 + 완료/전체 카운트 + 진행 바

struct SmallWidgetView: View {
    let data: WidgetSnapshotData?

    private var rate: Double    { data?.completionRate  ?? 0 }
    private var completed: Int  { data?.completedCount  ?? 0 }
    private var total: Int      { data?.totalCount      ?? 0 }
    private var planner: String { data?.plannerName     ?? "투두리포트" }

    var body: some View {
        contentView
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 플래너 이름
            Text(planner)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // 완료율 숫자
            Text("\(Int(rate * 100))%")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(nockOrange)

            // 완료 / 전체
            Text("\(completed)/\(total)개 완료")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            // 진행 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                    Capsule()
                        .fill(nockOrange)
                        .frame(width: geo.size.width * CGFloat(rate), height: 5)
                        .animation(.easeInOut(duration: 0.4), value: rate)
                }
            }
            .frame(height: 5)
            .padding(.top, 6)

            // 날짜
            Text(todayString)
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 6)
        }
        .padding(14)
        .widgetURL(URL(string: "todoreport://todo"))
        .containerBackground(.background, for: .widget)
    }

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M월 d일"
        fmt.locale = Locale(identifier: "ko_KR")
        return fmt.string(from: .now)
    }
}

// MARK: - Pro 잠금 안내

struct ProLockedWidgetView: View {
    var message: String

    var body: some View {
        if let paywallURL = URL(string: "todoreport://paywall") {
            Link(destination: paywallURL) {
                lockedContent
            }
        } else {
            lockedContent
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22))
                .foregroundStyle(nockOrange)
            Text("Pro 기능")
                .font(.caption.bold())
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - 색상 헬퍼 (Widget Extension은 Common/Colors.swift에 접근 불가)

private let nockOrange = Color(red: 0xFD / 255, green: 0x68 / 255, blue: 0x45 / 255)
