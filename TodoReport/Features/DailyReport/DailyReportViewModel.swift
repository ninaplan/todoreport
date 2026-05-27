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

    init(service: DailyReportService = DailyReportService()) {
        self.service = service
    }

    var hasUnsavedReview: Bool {
        reviewText != savedReview
    }

    // MARK: - Data

    func fetchReport(for date: Date, completionRate: Double) async {
        currentDate = date
        currentCompletionRate = completionRate

        guard let existing = await service.fetchReport(for: date) else {
            selectedRating = nil
            reviewText = ""
            savedReview = ""
            return
        }
        selectedRating = existing.dayRating
        reviewText = existing.review
        savedReview = existing.review
    }

    // MARK: - Actions

    func selectRating(_ rating: DayRating) async {
        selectedRating = (selectedRating == rating) ? nil : rating
        await saveReport()
    }

    func saveReport() async {
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
}
