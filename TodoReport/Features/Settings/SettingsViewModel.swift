import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    var showDeleteAccountAlert: Bool = false
    var showDeleteAccountFinalAlert: Bool = false
    var isDeletingAccount: Bool = false
    var deleteAccountError: String?

    private let onAccountDeleted: (() -> Void)?

    init(onAccountDeleted: (() -> Void)? = nil) {
        self.onAccountDeleted = onAccountDeleted
    }

    func requestDeleteAccount() {
        showDeleteAccountAlert = true
    }

    func cancelDeleteAccount() {
        showDeleteAccountAlert = false
        showDeleteAccountFinalAlert = false
    }

    func confirmDeleteAccountWarning() {
        showDeleteAccountAlert = false
        showDeleteAccountFinalAlert = true
    }

    func dismissDeleteAccountError() {
        deleteAccountError = nil
    }

    func performDeleteAccount(context: ModelContext) async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        cancelDeleteAccount()

        do {
            try await AccountDeletionService.shared.deleteAllAccountData(context: context)
            onAccountDeleted?()
        } catch {
            AppLogger.shared.error("SettingsViewModel", "계정 삭제 실패: \(error.localizedDescription)")
            #if DEBUG
            deleteAccountError = error.localizedDescription
            #else
            deleteAccountError = "삭제 중 오류가 발생했어요. 다시 시도해 주세요."
            #endif
        }
    }
}
