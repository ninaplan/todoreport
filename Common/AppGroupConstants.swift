import Foundation

enum AppGroupConstants {
    static let suiteName = "group.kr.nock.TodoReport"
    static let storeFileName = "TodoReport.store"
    static let legacyStoreFileName = "default.store"

    static let selectedPlannerIdKey = "selectedPlannerId"
    static let todoHideCompletedKey = "todoHideCompleted"
}

enum AppGroupUserDefaults {
    static var shared: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    static func selectedPlannerId() -> String? {
        if let groupId = shared?.string(forKey: AppGroupConstants.selectedPlannerIdKey), !groupId.isEmpty {
            return groupId
        }
        if let standardId = UserDefaults.standard.string(forKey: AppGroupConstants.selectedPlannerIdKey), !standardId.isEmpty {
            shared?.set(standardId, forKey: AppGroupConstants.selectedPlannerIdKey)
            return standardId
        }
        return nil
    }

    static func setSelectedPlannerId(_ id: String) {
        UserDefaults.standard.set(id, forKey: AppGroupConstants.selectedPlannerIdKey)
        shared?.set(id, forKey: AppGroupConstants.selectedPlannerIdKey)
    }

    static func todoHideCompleted() -> Bool {
        shared?.object(forKey: AppGroupConstants.todoHideCompletedKey) != nil
            ? (shared?.bool(forKey: AppGroupConstants.todoHideCompletedKey) ?? false)
            : UserDefaults.standard.bool(forKey: AppGroupConstants.todoHideCompletedKey)
    }

    static func setTodoHideCompleted(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: AppGroupConstants.todoHideCompletedKey)
        shared?.set(value, forKey: AppGroupConstants.todoHideCompletedKey)
    }

    static func syncTodoHideCompletedFromStandard() {
        setTodoHideCompleted(UserDefaults.standard.bool(forKey: AppGroupConstants.todoHideCompletedKey))
    }
}
