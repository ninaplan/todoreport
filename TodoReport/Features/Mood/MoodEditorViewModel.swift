import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MoodEditorViewModel {
    private(set) var options: [MoodOption] = []
    private(set) var mode: MoodStorageMode?
    private(set) var moodPropertyName: String?
    private(set) var isSavingEdit = false

    var isEditSheetPresented = false
    var editName = ""
    var editColorHex = MoodOption.palette[0]

    var showDeleteAlert = false
    private(set) var deletingOptionId: String?

    var showNotionNameChangeAlert = false
    var showSaveErrorAlert = false
    var showReadOnlyAlert = false

    private let plannerId: String
    private var editingId: String?
    private let service = MoodService.shared

    init(plannerId: String) {
        self.plannerId = plannerId
    }

    var isEditingOption: Bool { editingId != nil }

    var isUsageEnabled: Bool { mode != .disabled }

    var isNotionNameLocked: Bool { mode == .notion && isEditingOption }

    var modeDescription: String {
        switch mode {
        case .disabled:
            return String(localized: "사용 안 함")
        case .notion:
            let propertyName = resolvedPropertyName
            let safeName = propertyName.replacingOccurrences(of: "%", with: "%%")
            let template = String(localized: "노션 '%@' 속성과 연동 중")
            return String(format: template, locale: .current, safeName)
        case .appOnly, nil:
            return String(localized: "앱에서만 저장")
        }
    }

    func load() {
        refreshMode()
        do {
            options = try service.options(for: plannerId)
        } catch {
            presentSaveError()
        }
    }

    func setUsageEnabled(_ enabled: Bool) {
        guard enabled != isUsageEnabled else { return }
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        Task {
            do {
                try await service.setUsageEnabled(enabled, plannerId: plannerId)
                refreshMode()
                options = try service.options(for: plannerId)
            } catch {
                presentSaveError()
                refreshMode()
            }
        }
    }

    func setEditName(_ name: String) {
        editName = name
    }

    func selectColor(_ hex: String) {
        editColorHex = hex
    }

    func openAdd() {
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        editingId = nil
        editName = ""
        editColorHex = MoodOption.pickColor(used: Set(options.map(\.colorHex)))
        isEditSheetPresented = true
    }

    func displayName(for option: MoodOption) -> String {
        option.displayName(mode: mode)
    }

    func openEdit(_ option: MoodOption) {
        editingId = option.id
        editName = displayName(for: option)
        editColorHex = option.colorHex
        isEditSheetPresented = true
    }

    func dismissEditSheet() {
        isEditSheetPresented = false
    }

    func saveEdit() async {
        guard !isSavingEdit else { return }
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isNotionNameLocked, trimmed != editingOptionName {
            requestNotionNameChangeAlert()
            return
        }
        isSavingEdit = true
        defer { isSavingEdit = false }
        do {
            if let editingId {
                try service.updateOption(id: editingId, name: trimmed, colorHex: editColorHex)
            } else {
                _ = try service.addOption(name: trimmed, colorHex: editColorHex, plannerId: plannerId)
            }
            options = try service.options(for: plannerId)
            isEditSheetPresented = false
        } catch {
            presentSaveError()
        }
    }

    func moveOptions(from source: IndexSet, to destination: Int) {
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        var reordered = options
        reordered.move(fromOffsets: source, toOffset: destination)
        let previous = options
        options = reordered
        do {
            try service.reorder(ids: reordered.map(\.id), plannerId: plannerId)
        } catch {
            options = previous
            presentSaveError()
        }
    }

    func requestDelete(_ option: MoodOption) {
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        deletingOptionId = option.id
        showDeleteAlert = true
    }

    func cancelDelete() {
        deletingOptionId = nil
        showDeleteAlert = false
    }

    func confirmDelete() {
        guard let id = deletingOptionId else { return }
        showDeleteAlert = false
        deletingOptionId = nil
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return
        }
        do {
            try service.deleteOption(id: id)
            options.removeAll { $0.id == id }
        } catch {
            presentSaveError()
        }
    }

    func requestNotionNameChangeAlert() {
        showNotionNameChangeAlert = true
    }

    func cancelNotionNameChange() {
        showNotionNameChangeAlert = false
    }

    func confirmNotionNameChange() {
        showNotionNameChangeAlert = false
    }

    func cancelSaveError() {
        showSaveErrorAlert = false
    }

    func confirmSaveError() {
        showSaveErrorAlert = false
    }

    func cancelReadOnly() {
        showReadOnlyAlert = false
    }

    func confirmReadOnly() {
        showReadOnlyAlert = false
    }

    private var resolvedPropertyName: String {
        if let moodPropertyName, !moodPropertyName.isEmpty {
            return moodPropertyName
        }
        return String(localized: "기분")
    }

    private var editingOptionName: String? {
        guard let editingId else { return nil }
        return options.first { $0.id == editingId }?.name
    }

    private var isPlannerReadOnly: Bool {
        PlannerService.shared.store.first { $0.id == plannerId }?.isReadOnly ?? false
    }

    private func refreshMode() {
        let mapping = PlannerService.shared.store.first { $0.id == plannerId }?.decodedReportPropsMapping
        mode = mapping?.moodMode
        moodPropertyName = mapping?.mood
    }

    private func presentSaveError() {
        showSaveErrorAlert = true
    }

    private func presentReadOnly() {
        showReadOnlyAlert = true
    }
}
