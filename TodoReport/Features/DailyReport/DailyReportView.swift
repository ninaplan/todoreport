import SwiftUI

struct DailyReportCard: View {
    @Bindable var viewModel: DailyReportViewModel
    let date: Date
    let completionRate: Double

    @FocusState private var isReviewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ratingRow
            Divider()
            reviewRow
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: date) {
            await viewModel.fetchReport(for: date, completionRate: completionRate)
        }
        .onChange(of: completionRate) { _, newRate in
            viewModel.updateCompletionRate(newRate)
        }
        .onChange(of: isReviewFocused) { _, focused in
            guard !focused, viewModel.hasUnsavedReview else { return }
            Task { await viewModel.saveReport() }
        }
    }

    // MARK: - 별점 행

    private var ratingRow: some View {
        HStack(spacing: 0) {
            Text("별점")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(Array(DayRating.allCases.enumerated()), id: \.offset) { index, rating in
                    Button {
                        Task { await viewModel.selectRating(rating) }
                    } label: {
                        Text(isStarFilled(at: index) ? "⭐" : "☆")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    // MARK: - 리뷰 행

    private var reviewRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("하루 리뷰")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.hasUnsavedReview && isReviewFocused {
                    Button("저장") {
                        isReviewFocused = false
                        Task { await viewModel.saveReport() }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.nockOrange)
                }
            }

            TextField("오늘 하루 어떠셨나요?", text: $viewModel.reviewText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...5)
                .focused($isReviewFocused)
                .submitLabel(.done)
                .onSubmit {
                    Task { await viewModel.saveReport() }
                }
        }
    }

    // MARK: - Helpers

    private func isStarFilled(at index: Int) -> Bool {
        guard let selected = viewModel.selectedRating,
              let selectedIndex = DayRating.allCases.firstIndex(of: selected) else { return false }
        return index <= selectedIndex
    }
}
