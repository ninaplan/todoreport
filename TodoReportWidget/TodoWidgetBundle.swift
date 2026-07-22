import WidgetKit
import SwiftUI

// MARK: - Widget Bundle Entry Point
// ⚠️ 이 파일은 Widget Extension 타겟에 추가해야 합니다 (메인 앱 타겟 X)
// Xcode: File > New > Target > Widget Extension > "TodoReportWidget"

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
    }
}
