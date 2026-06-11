import SwiftUI

enum OnboardingWelcomePage: Int, CaseIterable, Identifiable {
    case brand
    case todoAndDaily
    case reports
    case captureAndSync
    case getStarted

    var id: Int { rawValue }

    /// 1페이지: PNG 스티커 로고. 2~4페이지: `lineSymbolName` 라인 아이콘. 5페이지: 정적 연결 아이콘.
    var usesBrandLogoAsset: Bool {
        self == .brand
    }

    var usesConnectionIcon: Bool {
        self == .getStarted
    }

    var lineSymbolName: String? {
        switch self {
        case .brand, .getStarted: return nil
        case .todoAndDaily:       return "list.bullet.clipboard"
        case .reports:            return "chart.line.uptrend.xyaxis"
        case .captureAndSync:     return "bolt.circle"
        }
    }

    var title: String {
        switch self {
        case .brand:           return "투두리포트"
        case .todoAndDaily:    return "오늘의 할 일과 기록"
        case .reports:         return "주간·월간으로 돌아보기"
        case .captureAndSync:  return "빠르게 기록, 자동 동기화"
        case .getStarted:      return "이제 시작해볼까요?"
        }
    }

    var subtitle: String {
        switch self {
        case .brand:
            return "앱에서 기록하고, 노션에 쌓아가세요"
        case .todoAndDaily:
            return "투두 작성·완료 체크부터 하루 리뷰와 별점까지 한곳에서 관리해요"
        case .reports:
            return "완료율 그래프, 별점 흐름, 카테고리 달성률로 패턴을 파악하고 노션에 리포트를 남겨요"
        case .captureAndSync:
            return "생각날 때 바로 추가하고, 오프라인에서도 저장한 뒤 노션에 자동으로 전송돼요"
        case .getStarted:
            return "노션과 연결하면 투두·리포트를 DB에 저장하고 노션에서 관리할 수 있어요."
        }
    }

    var showsBrandAccent: Bool {
        self == .brand
    }
}
