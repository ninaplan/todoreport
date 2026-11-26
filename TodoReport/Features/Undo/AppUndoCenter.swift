import Foundation
import Observation
import SwiftUI
import UIKit

/// 앱 전체 되돌리기 창구. **직전 작업 1개만** 기억한다 (다음 작업·플래너 전환·앱 종료 전까지 유지).
/// - 흔들기: `ShakeDetector`가 알려 주면 「실행 취소」 확인 창을 띄운다 (설정 > 손쉬운 사용 > 흔들어서 실행 취소를 따름)
/// - 배너: 확인 없이 바로 지우는 작업만 화면 아래 「실행 취소」 배너를 함께 띄운다
/// 기능 모듈은 `register`만 부르고, 되돌리는 방법은 각자 서비스 함수로 넘긴다 (모듈 독립).
@Observable
final class AppUndoCenter {
    static let shared = AppUndoCenter()
    private init() {}

    /// 지금 떠 있는 배너. nil이면 없음
    private(set) var banner: UndoBanner?

    @ObservationIgnored private var record: UndoRecord?
    @ObservationIgnored private var bannerDismissTask: Task<Void, Never>?
    @ObservationIgnored private weak var shakeAlert: UIAlertController?

    private static let bannerDuration: Duration = .seconds(4)

    // MARK: - 등록

    /// 직전 작업 등록. 이전 기록은 버린다.
    /// - Parameters:
    ///   - confirmTitle: 흔들었을 때 확인 창 제목 한 줄 — 할 일 이름과 되돌릴 내용 (예: 「'앱 홍보' 삭제를 되돌릴까요?」)
    ///   - bannerMessage: 배너 문구. nil이면 배너 없이 흔들기로만 되돌린다
    ///   - bannerScope: 배너를 띄울 화면
    func register(
        confirmTitle: String,
        bannerMessage: String? = nil,
        bannerScope: UndoBannerScope = .todo,
        undo: @escaping @MainActor () async -> Void
    ) {
        let newRecord = UndoRecord(
            id: UUID(),
            plannerId: PlannerService.shared.selectedPlanner?.id,
            confirmTitle: confirmTitle,
            undo: undo
        )
        record = newRecord
        shakeAlert?.dismiss(animated: false)
        if let bannerMessage {
            showBanner(UndoBanner(id: newRecord.id, message: bannerMessage, scope: bannerScope))
        } else {
            dismissBanner()
        }
    }

    // MARK: - 되돌리기

    /// 배너 「실행 취소」
    func performUndo() {
        guard let current = record else { return }
        run(current)
    }

    func dismissBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        guard banner != nil else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            banner = nil
        }
    }

    /// 기록까지 비움 (플래너 전환 등)
    func clear() {
        record = nil
        shakeAlert?.dismiss(animated: false)
        dismissBanner()
    }

    // MARK: - 흔들기

    /// 흔들었을 때. 되돌릴 작업이 있으면 「실행 취소」 확인 창 (실수로 흔든 경우를 위해 바로 되돌리지 않는다)
    func handleShake() {
        guard let current = record else { return }
        guard UIAccessibility.isShakeToUndoEnabled else { return }
        guard shakeAlert == nil else { return }
        guard let window = Self.keyWindow, let presenter = Self.topViewController(from: window.rootViewController) else { return }
        // 글자 입력 중이면 시스템 「입력 실행 취소」가 뜨므로 겹치지 않게 비켜 준다
        guard !Self.hasTextInputFirstResponder(in: window) else { return }

        let recordId = current.id
        // 제목 한 줄로 무엇이 돌아오는지 알려 준다. 버튼은 「취소 / 되돌리기」 (「취소 / 실행 취소」는 헷갈림)
        let alert = UIAlertController(
            title: current.confirmTitle,
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "취소"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "되돌리기"), style: .default) { [weak self] _ in
            guard let self, let latest = self.record, latest.id == recordId else { return }
            self.run(latest)
        })
        shakeAlert = alert
        presenter.present(alert, animated: true)
    }

    // MARK: - Private

    private func run(_ current: UndoRecord) {
        record = nil
        dismissBanner()
        // 다른 플래너로 바뀐 뒤에는 보이지 않는 곳이 바뀌어 헷갈리므로 되돌리지 않는다
        guard current.plannerId == PlannerService.shared.selectedPlanner?.id else { return }
        Task { @MainActor in
            await current.undo()
        }
    }

    private func showBanner(_ newBanner: UndoBanner) {
        bannerDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) {
            banner = newBanner
        }
        UIAccessibility.post(notification: .announcement, argument: newBanner.message)
        let bannerId = newBanner.id
        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.bannerDuration)
            guard !Task.isCancelled, let self, self.banner?.id == bannerId else { return }
            self.dismissBanner()
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    /// 시트·팝업이 떠 있으면 그 위에서 확인 창을 띄운다
    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        var current = root
        while let presented = current?.presentedViewController, !presented.isBeingDismissed {
            current = presented
        }
        return current
    }

    private static func hasTextInputFirstResponder(in view: UIView) -> Bool {
        if view.isFirstResponder, view is UITextField || view is UITextView { return true }
        return view.subviews.contains { hasTextInputFirstResponder(in: $0) }
    }
}
