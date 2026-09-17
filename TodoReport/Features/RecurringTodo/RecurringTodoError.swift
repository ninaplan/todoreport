import Foundation

enum RecurringTodoError: Error {
    case ruleEncodingFailed
    case missingOriginDate
    case missingRule
    case storeFetchFailed
    case requiresPro
}
