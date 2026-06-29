import SwiftUI
import UIKit

struct DailyReportCard: View {
    @Bindable var viewModel: DailyReportViewModel
    let date: Date
    let completionRate: Double      // Notion 저장용 (전체 기준)
    let displayRate: Double         // UI 표시용 (필터 반영)
    let displayCompleted: Int
    let displayTotal: Int

    @FocusState private var isReviewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            completionRateSection
            Divider()
            ratingRow
            Divider()
            reviewRow
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .sensoryFeedback(.selection, trigger: viewModel.ratingHapticTrigger)
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

    // MARK: - 완료율

    private var completionRateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("완료율")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(displayCompleted)/\(displayTotal)개  \(Int(displayRate * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            ProgressView(value: displayRate)
                .tint(AppTheme.shared.accent)
                .scaleEffect(y: 1.4)
        }
    }

    // MARK: - 별점 행

    private var ratingRow: some View {
        HStack(spacing: 0) {
            Text("별점")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            PawRatingView(
                rating: currentRatingCount,
                interactive: true,
                size: 24,
                spacing: 8,
                onTap: { count in
                    let tapped = DayRating.allCases[count - 1]
                    let newRating: DayRating? = (viewModel.selectedRating == tapped) ? nil : tapped
                    Task { await viewModel.selectRating(newRating) }
                }
            )

            Spacer()

            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private var currentRatingCount: Int {
        guard let selected = viewModel.selectedRating,
              let idx = DayRating.allCases.firstIndex(of: selected) else { return 0 }
        return idx + 1
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
                    .foregroundStyle(AppTheme.shared.accent)
                }
            }

            TextField("오늘 하루 어떠셨나요?", text: $viewModel.reviewText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...5)
                .focused($isReviewFocused)
                .submitLabel(.done)
                .onSubmit {
                    isReviewFocused = false
                }
                .onChange(of: viewModel.reviewText) { _, newValue in
                    guard newValue.hasSuffix("\n") else { return }
                    isReviewFocused = false
                }
        }
    }

}

