import Foundation
import UIKit

enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO "
    case warn  = "WARN "
    case error = "ERROR"
}

@Observable
final class AppLogger {
    static let shared = AppLogger()
    private init() {}

    private let fileName = "app_logs.txt"
    private let maxFileSizeBytes: Int = 1024 * 512  // 500KB 초과 시 오래된 절반 삭제

    private var logFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    // MARK: - 로그 기록

    func log(_ level: LogLevel, _ module: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] [\(module)] \(message)\n"

        #if DEBUG
        print(line, terminator: "")
        #endif

        appendToFile(line)
    }

    func debug(_ module: String, _ message: String) { log(.debug, module, message) }
    func info(_ module: String, _ message: String)  { log(.info,  module, message) }
    func warn(_ module: String, _ message: String)  { log(.warn,  module, message) }
    func error(_ module: String, _ message: String) { log(.error, module, message) }

    // MARK: - 파일 관리

    private func appendToFile(_ text: String) {
        guard let url = logFileURL else { return }
        guard let data = text.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: url.path) {
            trimIfNeeded(url: url)
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func trimIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > maxFileSizeBytes else { return }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        let trimmed = lines.dropFirst(lines.count / 2).joined(separator: "\n")
        try? trimmed.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - 내보내기

    func exportLogFileURL() -> URL? {
        guard let url = logFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        print("[AppLogger] export 시도 - exists: \(FileManager.default.fileExists(atPath: url.path))")
        return url
    }

    func clearLogs() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func resetWithHeader() {
        clearLogs()
        writeSessionHeader()
    }

    func logNewSession() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device  = UIDevice.current.model
        let os      = UIDevice.current.systemVersion
        let line = "--- 세션 시작 \(ISO8601DateFormatter().string(from: Date())) | v\(version)(\(build)) \(device) iOS\(os) ---\n"
        appendToFile(line)
    }

    // MARK: - 앱 정보 헤더

    func writeSessionHeader() {
        print("[AppLogger] logFileURL: \(logFileURL?.path ?? "nil")")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device  = UIDevice.current.model
        let os      = UIDevice.current.systemVersion
        let header = "========================================\n" +
                     "투두리포트 v\(version) (\(build))\n" +
                     "기기: \(device) / iOS \(os)\n" +
                     "세션 시작: \(ISO8601DateFormatter().string(from: Date()))\n" +
                     "========================================\n"
        appendToFile(header)
    }
}
