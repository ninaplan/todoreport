import Combine
import SwiftUI
import UIKit
import SafariServices
import Security

@MainActor
final class NotionAuthManager: NSObject, ObservableObject, SFSafariViewControllerDelegate {
    static let shared = NotionAuthManager()

    // Legacy: readable for resolvedNotionToken fallback and migration
    private(set) var accessToken: String?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    // 항상 이 콜백을 통해 토큰 전달 (플래너 모델에 직접 저장)
    var secondaryOAuthCompletion: ((String) -> Void)?
    var oAuthCancelledCompletion: (() -> Void)?

    private var pendingState: String?
    private var safariVC: SFSafariViewController?

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
        let state = UUID().uuidString
        pendingState = state
        guard let url = URL(string: "https://todoreport-backend.vercel.app/api/auth/notion?state=\(state)") else {
            return
        }
        isLoading = true
        print("[NotionAuth] 🚀 OAuth 시작")
        let safari = SFSafariViewController(url: url)
        safari.delegate = self
        safari.modalPresentationStyle = .pageSheet
        safariVC = safari
        topViewController()?.present(safari, animated: true)
    }

    nonisolated func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo url: URL) {
        print("[NotionAuth] 🔀 리다이렉트 감지: \(url)")
        guard url.scheme == "todoreport" else { return }
        Task { @MainActor in
            self.safariVC?.dismiss(animated: true)
            self.safariVC = nil
            self.handleCallback(url: url)
        }
    }

    nonisolated func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor in
            self.isLoading = false
            self.safariVC = nil
            self.oAuthCancelledCompletion?()
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top: UIViewController = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    func handleCallback(url: URL) {
        guard url.scheme == "todoreport" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params: [String: String] = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        if url.host == "auth" && url.path == "/callback" {
            guard let token = params["access_token"] else {
                errorMessage = "인증 응답 파싱 실패"
                isLoading = false
                print("[NotionAuth] ❌ 콜백 파싱 실패 - url: \(url)")
                return
            }

            isLoading = false
            safariVC?.dismiss(animated: true)
            safariVC = nil

            if let completion = secondaryOAuthCompletion {
                secondaryOAuthCompletion = nil
                completion(token)
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
        keychainDelete(key: Key.accessToken)
        keychainDelete(key: Key.workspaceId)
        keychainDelete(key: Key.workspaceName)
        keychainDelete(key: Key.botId)
        accessToken = nil
        errorMessage = nil
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
