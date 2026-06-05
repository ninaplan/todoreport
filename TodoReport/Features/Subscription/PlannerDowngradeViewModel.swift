import Foundation
import Observation

@Observable
final class PlannerDowngradeViewModel {
    private(set) var planners: [Planner] = []
    var selectedPlannerId: String = ""
    private(set) var isConfirmed: Bool = false

    func load() {
        planners = PlannerService.shared.store
        selectedPlannerId = PlannerService.shared.selectedPlannerId
    }

    func confirmDowngrade() {
        guard !selectedPlannerId.isEmpty else { return }
        PlannerService.shared.downgradeToFree(keepPlannerId: selectedPlannerId)
        isConfirmed = true
    }
}
