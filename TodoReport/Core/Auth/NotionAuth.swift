import AuthenticationServices
import Combine
import SwiftUI
import UIKit
import Security

@MainActor
final class NotionAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = NotionAuthManager()

    private static let callbackURLScheme = "todoreport"

    // Legacy: readable for resolvedNotionToken fallback and migration
    private(set) var accessToken: String?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    // 항상 이 콜백을 통해 토큰 전달 (플래너 모델에 직접 저장)
    var secondaryOAuthCompletion: ((String, String?, String, String, String?) -> Void)?
    var oAuthCancelledCompletion: (() -> Void)?

    private var pendingState: String?
    private var authSession: ASWebAuthenticationSession?

    private enum Key {
        static let accessToken   = "kr.nock.TodoReport.accessToken"
        static let workspaceId   = "kr.nock.TodoReport.workspaceId"
        static let workspaceName = "kr.nock.TodoReport.workspaceName"
        static let botId         = "kr.nock.TodoReport.botId"
    }

    private override init() {
        super.init()
        // 레거시 Keychain에서 읽기 (마이그레이션 전 fallback용)
        accessToken = keychainRead(key: Key.accessToken)
    }

    func startOAuth() {
        authSession?.cancel()
        authSession = nil

        let state = UUID().uuidString
        pendingState = state
        guard let url = URL(string: "\(BackendBaseURL.resolved)/api/auth/notion?state=\(state)") else {
            return
        }
        isLoading = true
        print("[NotionAuth] 🚀 OAuth 시작")

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: Self.callbackURLScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authSession = nil

                if let error {
                    self.isLoading = false
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        self.oAuthCancelledCompletion?()
                        print("[NotionAuth] OAuth 취소")
                    } else {
                        self.errorMessage = error.localizedDescription
                        print("[NotionAuth] ❌ OAuth 실패: \(error.localizedDescription)")
                    }
                    return
                }

                guard let callbackURL else {
                    self.isLoading = false
                    self.errorMessage = "인증 응답을 받지 못했어요"
                    print("[NotionAuth] ❌ 콜백 URL 없음")
                    return
                }

                self.handleCallback(url: callbackURL)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        authSession = session

        if !session.start() {
            isLoading = false
            errorMessage = "인증 세션을 시작할 수 없어요"
            authSession = nil
            print("[NotionAuth] ❌ ASWebAuthenticationSession.start() 실패")
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = keyWindow() {
            return window
        }
        if let scene = activeWindowScene()
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            return UIWindow(windowScene: scene)
        }
        AppLogger.shared.error("NotionAuth", "presentationAnchor: UIWindowScene 없음")
        #if DEBUG
        fatalError("UIWindowScene required for OAuth presentation")
        #else
        return UIWindow(windowScene: UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!)
        #endif
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    private func keyWindow() -> UIWindow? {
        guard let activeScene = activeWindowScene() else { return nil }
        return activeScene.windows.first(where: { $0.isKeyWindow }) ?? activeScene.windows.first
    }

    func handleCallback(url: URL) {
        guard url.scheme == Self.callbackURLScheme else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params: [String: String] = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        if url.host == "auth" && url.path == "/callback" {
            guard let token = params["access_token"],
                  let workspaceId = params["workspace_id"],
                  let workspaceName = params["workspace_name"] else {
                errorMessage = "인증 응답 파싱 실패"
                isLoading = false
                print("[NotionAuth] ❌ 콜백 파싱 실패 - url: \(url)")
                return
            }

            isLoading = false

            let refreshToken = params["refresh_token"]
            let botId = params["bot_id"]

            if let completion = secondaryOAuthCompletion {
                secondaryOAuthCompletion = nil
                completion(token, refreshToken, workspaceId, workspaceName, botId)
                print("[NotionAuth] ✅ OAuth 완료 - 플래너 콜백 전달")
            } else {
                print("[NotionAuth] ⚠️ secondaryOAuthCompletion 미설정 - 토큰 드롭")
            }

        } else if url.host == "auth" && url.path == "/error" {
            let reason = params["reason"]?.removingPercentEncoding ?? params["reason"] ?? "알 수 없는 오류"
            errorMessage = reason
            isLoading = false
            print("[NotionAuth] ❌ 에러 콜백 - reason: \(reason)")
        }
    }

    // 레거시 Keychain 토큰 읽기 (마이그레이션 전용)
    func readLegacyAccessToken() -> String? {
        keychainRead(key: Key.accessToken)
    }

    func signOut() {
        authSession?.cancel()
        authSession = nil
        pendingState = nil
        secondaryOAuthCompletion = nil
        oAuthCancelledCompletion = nil
        isLoading = false

        keychainDelete(key: Key.accessToken)
        keychainDelete(key: Key.workspaceId)
        keychainDelete(key: Key.workspaceName)
        keychainDelete(key: Key.botId)
        accessToken = nil
        errorMessage = nil
    }

    /// 계정 삭제 후 Keychain 잔존 여부 확인용
    func hasLegacyKeychainCredentials() -> Bool {
        [Key.accessToken, Key.workspaceId, Key.workspaceName, Key.botId]
            .contains { keychainRead(key: $0) != nil }
    }

    /// in-memory accessToken 존재 여부 (init 시 Keychain에서 로드된 value)
    func hasInMemoryAccessToken() -> Bool {
        accessToken != nil
    }

    func currentAccessToken() -> String? {
        accessToken
    }

    // MARK: - Keychain

    private func keychainRead(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func keychainWrite(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var insert = query
            insert[kSecValueData] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private func keychainDelete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
