import AuthenticationServices
import SwiftUI

@MainActor
final class NotionAuthManager: NSObject, ObservableObject {
    static let shared = NotionAuthManager()

    @Published private(set) var accessToken: String?
    @Published private(set) var workspaceId: String?
    @Published private(set) var workspaceName: String?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var authSession: ASWebAuthenticationSession?
    private let backendBaseURL = "https://todoreport-backend.vercel.app"

    private override init() {}

    // MARK: - OAuth 시작

    func startOAuth(presentationAnchor: ASPresentationAnchor) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let state = UUID().uuidString

        guard let authURL = URL(string: "\(backendBaseURL)/api/auth/notion?state=\(state)") else {
            isLoading = false
            errorMessage = "Invalid auth URL"
            return
        }

        await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "todoreport"
            ) { [weak self] callbackURL, error in
                guard let self else {
                    continuation.resume()
                    return
                }
                Task { @MainActor in
                    self.handleCallback(url: callbackURL, error: error)
                    self.isLoading = false
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    // MARK: - 콜백 처리

    private func handleCallback(url: URL?, error: Error?) {
        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
            errorMessage = "인증이 취소되었습니다."
            return
        }

        guard let url else {
            errorMessage = "인증 응답을 받지 못했습니다."
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        // 에러 경로: todoreport://auth/error?reason=...
        if url.host == "auth" && url.path == "/error" {
            let reason = params["reason"] ?? "unknown"
            errorMessage = "인증 실패: \(reason)"
            return
        }

        // 성공 경로: todoreport://auth/callback?access_token=...
        guard
            url.host == "auth",
            url.path == "/callback",
            let token = params["access_token"],
            let wsId = params["workspace_id"]
        else {
            errorMessage = "인증 응답 형식이 올바르지 않습니다."
            return
        }

        accessToken = token
        workspaceId = wsId
        workspaceName = params["workspace_name"].map {
            $0.removingPercentEncoding ?? $0
        }
        isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "isNotionConnected")
    }

    // MARK: - 로그아웃

    func signOut() {
        accessToken = nil
        workspaceId = nil
        workspaceName = nil
        isAuthenticated = false
        errorMessage = nil
        UserDefaults.standard.set(false, forKey: "isNotionConnected")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension NotionAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
