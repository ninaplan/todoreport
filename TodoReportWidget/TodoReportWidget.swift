import WidgetKit
import SwiftUI

struct TodoReportWidget: Widget {
    let kind = "kr.nock.TodoReport.Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("투두리포트")
        .description("오늘의 투두와 완료율을 홈 화면에서 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TodoReportWidget()
} timeline: {
    WidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    TodoReportWidget()
} timeline: {
    WidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    TodoReportWidget()
} timeline: {
    WidgetEntry.placeholder
}
