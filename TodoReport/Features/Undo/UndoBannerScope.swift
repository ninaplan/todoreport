import Foundation

/// 「실행 취소」 배너를 띄울 화면. 화면마다 배너 자리가 달라서(투두 탭은 FAB 옆, 수집함은 시트 안) 나눈다.
enum UndoBannerScope: Equatable {
    case todo
    case inbox
    case timeBlock
}
