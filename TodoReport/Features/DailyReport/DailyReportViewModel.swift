import Foundation

@Observable
final class DailyReportViewModel {
    private(set) var isSaving: Bool = false

    var selectedRating: DayRating? = nil
    var reviewText: String = ""

    private var currentDate: Date = .now
    private var currentCompletionRate: Double = 0
    private var savedReview: String = ""
    private let service: DailyReportService
    private var fetchTask: Task<Void, Never>?

    init(service: DailyReportService = DailyReportService()) {
        self.service = service
    }

    var hasUnsavedReview: Bool {
        reviewText != savedReview
    }

    // MARK: - Data

    func switchReport() {
        fetchTask?.cancel()
        fetchTask = nil
        selectedRating = nil
        reviewText = ""
        savedReview = ""
    }

    func fetchReport(for date: Date, completionRate: Double) async {
        fetchTask?.cancel()
        currentDate = date
        currentCompletionRate = completionRate

        if let existing = await service.fetchReport(for: date) {
            selectedRating = existing.dayRating
            reviewText = existing.review
            savedReview = existing.review
        } else {
            selectedRating = nil
            reviewText = ""
            savedReview = ""
        }

        let d = date
        fetchTask = Task {
            await service.syncReportFromNotion(for: d)
            guard !Task.isCancelled else { return }
            if let synced = await service.fetchReport(for: d) {
                selectedRating = synced.dayRating
                if !hasUnsavedReview {
                    reviewText = synced.review
                    savedReview = synced.review
                }
            }
        }
    }

    // MARK: - Actions

    func selectRating(_ rating: DayRating) async {
        selectedRating = rating
        await saveReport()
    }

    func saveReport() async {
        stripTrailingNewline()
        isSaving = true
        defer { isSaving = false }

        let report = DailyReport(
            date: currentDate,
            review: reviewText,
            completionRate: currentCompletionRate,
            dayRating: selectedRating
        )
        try? await service.saveReport(report)
        savedReview = reviewText
    }

    func updateCompletionRate(_ rate: Double) {
        currentCompletionRate = rate
    }

    func stripTrailingNewline() {
        if reviewText.hasSuffix("\n") {
            reviewText = String(reviewText.dropLast())
        }
    }
}
