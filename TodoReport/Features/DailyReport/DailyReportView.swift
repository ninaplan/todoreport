import SwiftUI
import UIKit

struct DailyReportCard: View {
    @Bindable var viewModel: DailyReportViewModel
    let date: Date
    let completionRate: Double      // Notion 저장용 (전체 기준)
    let displayRate: Double         // UI 표시용 (필터 반영)
    let displayCompleted: Int
    let displayTotal: Int

    @State private var isExpanded = false
    @State private var expandedContentHeight: CGFloat = 0
    @FocusState private var isReviewFocused: Bool

    var body: some View {
        // 헤더는 레이아웃상 고정. 하단만 height 0↔측정값 + clipped로 아래로 reveal.
        // withAnimation+if 삽입은 List 행 높이 애니메이션과 겹쳐 헤더가 출렁이므로 쓰지 않음.
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .zIndex(1)

            expandedContent(forMeasurement: false)
                .padding(.top, 12)
                .frame(height: isExpanded ? expandedContentHeight : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)
        }
        .background(alignment: .top) {
            // 접힌 상태에서도 고유 높이를 재기 위한 측정용(레이아웃 영향 없음)
            Color.clear
                .frame(height: 0)
                .overlay(alignment: .top) {
                    expandedContent(forMeasurement: true)
                        .padding(.top, 12)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            guard newHeight > 0, abs(expandedContentHeight - newHeight) > 0.5 else { return }
                            expandedContentHeight = newHeight
                        }
                }
        }
        // 곡선 후보: .spring(response: 0.4, dampingFraction: 0.85) | .smooth(duration: 0.4)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .geometryGroup()
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

    // MARK: - 헤더 (접기/펼치기)

    private var headerRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack {
                Text("데일리 리포트")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func expandedContent(forMeasurement: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            completionRateSection
            Divider()
            ratingRow
            Divider()
            reviewRow(forMeasurement: forMeasurement)
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

    @ViewBuilder
    private func reviewRow(forMeasurement: Bool) -> some View {
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

            // 측정용은 .focused 미연결 — 동일 폰트·lineLimit·텍스트로 높이만 맞춤
            if forMeasurement {
                TextField("오늘 하루 어떠셨나요?", text: $viewModel.reviewText, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(2...5)
            } else {
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

}

