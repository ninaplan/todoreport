import Foundation
import Observation

@MainActor
@Observable
final class MoodButtonViewModel {
    private(set) var options: [MoodOption] = []
    private(set) var selectedOptionId: String?
    private(set) var snapshotName: String?
    private(set) var isReady = false
    private(set) var plannerId = ""
    var showEditor = false
    var showSaveErrorAlert = false
    var showReadOnlyAlert = false

    private var date: Date?
    private var loadToken = UUID()
    /// 화면에서 고른 직후 진행 중인 저장. reload가 이 선택을 덮어쓰지 않게 한다.
    @ObservationIgnored private var persistGeneration = 0
    private let service = MoodService.shared

    var showsClear: Bool {
        if selectedOptionId != nil { return true }
        if let snapshotName, !snapshotName.isEmpty { return true }
        return false
    }

    var chipTitle: String {
        if let selectedOptionId, let option = options.first(where: { $0.id == selectedOptionId }) {
            return displayName(for: option)
        }
        if let snapshotName {
            let resolved = MoodOption.displayName(
                storedName: snapshotName,
                defaultKey: nil,
                mode: storageMode
            )
            if !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return resolved
            }
        }
        return String(localized: "기분")
    }

    func displayName(for option: MoodOption) -> String {
        option.displayName(mode: storageMode)
    }

    private var storageMode: MoodStorageMode? {
        PlannerService.shared.store
            .first { $0.id == plannerId }?
            .decodedReportPropsMapping.moodMode
    }

    var chipColorHex: String? {
        guard let selectedOptionId,
              let option = options.first(where: { $0.id == selectedOptionId }) else {
            return nil
        }
        return option.colorHex
    }

    var accessibilityValueText: String {
        if showsClear { return chipTitle }
        return String(localized: "선택 안 됨")
    }

    func reload(date: Date, plannerId: String) async {
        let generation = persistGeneration
        let token = UUID()
        loadToken = token
        self.date = date
        self.plannerId = plannerId
        guard !plannerId.isEmpty else {
            options = []
            selectedOptionId = nil
            snapshotName = nil
            isReady = true
            return
        }
        do {
            let loadedOptions = try service.options(for: plannerId)
            let loadedSelection = try service.selection(on: date, plannerId: plannerId)
            guard loadToken == token else { return }
            if options != loadedOptions {
                options = loadedOptions
            }
            guard generation == persistGeneration else {
                isReady = true
                return
            }
            selectedOptionId = loadedSelection.optionId
            snapshotName = loadedSelection.name
            isReady = true
        } catch {
            guard loadToken == token else { return }
            isReady = true
            presentSaveError()
        }
    }

    func select(optionId: String) {
        let previous = (selectedOptionId, snapshotName)
        guard applyOptimistic(optionId: optionId) else { return }
        persist(optionId: optionId, previous: previous)
    }

    func clear() {
        let previous = (selectedOptionId, snapshotName)
        guard applyOptimistic(optionId: nil) else { return }
        persist(optionId: nil, previous: previous)
    }

    func openEditor() {
        guard !plannerId.isEmpty else { return }
        showEditor = true
    }

    func dismissEditor() {
        showEditor = false
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

    private func applyOptimistic(optionId: String?) -> Bool {
        guard date != nil, !plannerId.isEmpty else { return false }
        guard !isPlannerReadOnly else {
            presentReadOnly()
            return false
        }
        persistGeneration += 1
        selectedOptionId = optionId
        if let optionId {
            snapshotName = options.first { $0.id == optionId }?.name
        } else {
            snapshotName = nil
        }
        return true
    }

    private func persist(
        optionId: String?,
        previous: (String?, String?)
    ) {
        let generation = persistGeneration
        guard let date, !plannerId.isEmpty else { return }
        let savedDate = date
        let savedPlannerId = plannerId
        Task {
            do {
                try service.setMood(optionId: optionId, on: savedDate, plannerId: savedPlannerId)
            } catch {
                guard generation == persistGeneration else { return }
                guard self.date == savedDate, self.plannerId == savedPlannerId else { return }
                selectedOptionId = previous.0
                snapshotName = previous.1
                presentSaveError()
            }
        }
    }

    private var isPlannerReadOnly: Bool {
        PlannerService.shared.store.first { $0.id == plannerId }?.isReadOnly ?? false
    }

    private func presentSaveError() {
        showSaveErrorAlert = true
    }

    private func presentReadOnly() {
        showReadOnlyAlert = true
    }
}
