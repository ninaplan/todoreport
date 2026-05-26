import Foundation
import AuthenticationServices

@Observable
final class OnboardingViewModel {

    enum Step: Equatable {
        case signIn
        case connectionChoice
        case notionOAuth
        case localModeInfo
    }

    private(set) var step: Step = .signIn
    private(set) var isLoading: Bool = false
    private(set) var isComplete: Bool = false
    private(set) var alertMessage: String?

    // MARK: - Step 1: Sign in with Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            step = .connectionChoice
        case .failure(let error):
            // 사용자가 직접 취소한 경우 에러 표시 안 함
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            alertMessage = error.localizedDescription
        }
    }

    // MARK: - Step 2: Connection Choice

    func selectNotionConnection() {
        step = .notionOAuth
    }

    func selectLocalMode() {
        step = .localModeInfo
    }

    // MARK: - Step 3: Notion OAuth

    func startNotionOAuth() async {
        isLoading = true
        // TODO: Core/Auth/NotionAuth.swift 구현 후 연동
        // ASWebAuthenticationSession으로 Notion OAuth 진행
        // 완료 시 UserDefaults.standard.set(true, forKey: "notionConnected") 후 isComplete = true
        isLoading = false
    }

    // MARK: - Step 4: Local Mode

    func completeWithLocalMode() {
        UserDefaults.standard.set(false, forKey: "notionConnected")
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        isComplete = true
    }

    // MARK: - Utility

    func clearAlert() {
        alertMessage = nil
    }

    // TODO: 배포 전 제거 — 개발 테스트용
    func devLogin() {
        step = .connectionChoice
    }
}
