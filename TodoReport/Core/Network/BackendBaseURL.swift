import Foundation

enum BackendBaseURL {
    static let production = "https://todoreport-backend.vercel.app"

    static var resolved: String {
        #if DEBUG
        return debugResolved
        #else
        return production
        #endif
    }

    #if DEBUG
    private static let overrideKey = "debugBackendBaseURLOverride"

    static var overrideValue: String? {
        UserDefaults.standard.string(forKey: overrideKey)
    }

    static func applyOverride(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(normalized(trimmed), forKey: overrideKey)
    }

    static func resetToProduction() {
        UserDefaults.standard.removeObject(forKey: overrideKey)
    }

    private static var debugResolved: String {
        guard let override = overrideValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !override.isEmpty else {
            return production
        }
        return normalized(override)
    }

    private static func normalized(_ url: String) -> String {
        var result = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
    #endif
}
