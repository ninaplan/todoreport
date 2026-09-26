import SwiftUI
import UIKit

struct DailyReportCard: View {
    @Bindable var viewModel: DailyReportViewModel
    let date: Date
    let completionRate: Double      // Notion 저장용 (전체 기준)
    let displayRate: Double         // UI 표시용 (오늘 전체 기준)
    let displayCompleted: Int
    let displayTotal: Int
    /// 최초 1회, 리포트 카드가 처음 나타났을 때 호출 (화살표 안내 말풍선은 List 밖 상위 뷰에서 표시)
    var onFirstAppear: (() -> Void)? = nil
    var expandToken: Int = 0

    @State private var isExpanded = false
    @State private var lastAppliedExpandToken = 0
    @State private var expandedContentHeight: CGFloat = 0
    @State private var moodButtonViewModel = MoodButtonViewModel()
    @State private var moodChipFrame: CGRect = .zero
    @State private var moodEditorPresented = false
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
                        .id(showsMoodChip)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            guard newHeight > 0, abs(expandedContentHeight - newHeight) > 0.5 else { return }
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                expandedContentHeight = newHeight
                            }
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
        .onAppear {
            onFirstAppear?()
            applyExpandTokenIfNeeded()
        }
        .onChange(of: expandToken) { _, _ in
            applyExpandTokenIfNeeded()
        }
        .onChange(of: moodButtonViewModel.showEditor) { _, show in
            if show { moodEditorPresented = true }
        }
        .onChange(of: showsMoodChip) { _, shown in
            if !shown { moodButtonViewModel.dismissEditor() }
        }
        .sheet(isPresented: Binding(
            get: { moodEditorPresented },
            set: { isPresented in
                moodEditorPresented = isPresented
                if !isPresented { moodButtonViewModel.dismissEditor() }
            }
        )) {
            NavigationStack {
                MoodEditorView(
                    plannerId: PlannerService.shared.selectedPlannerId,
                    presentsAsSheet: true
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func applyExpandTokenIfNeeded() {
        guard expandToken > 0, expandToken != lastAppliedExpandToken else { return }
        lastAppliedExpandToken = expandToken
        isExpanded = true
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
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func expandedContent(forMeasurement: Bool) -> some View {
        let stack = expandedStack(forMeasurement: forMeasurement)
        if forMeasurement {
            stack
        } else {
            stack
                .backgroundPreferenceValue(MoodChipAnchorKey.self) { anchor in
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: MoodChipFrameKey.self,
                                value: anchor.map { proxy[$0] } ?? .zero
                            )
                    }
                    .allowsHitTesting(false)
                }
                .onPreferenceChange(MoodChipFrameKey.self) { frame in
                    guard abs(frame.minX - moodChipFrame.minX) > 0.5
                            || abs(frame.minY - moodChipFrame.minY) > 0.5
                            || abs(frame.width - moodChipFrame.width) > 0.5
                            || abs(frame.height - moodChipFrame.height) > 0.5 else { return }
                    moodChipFrame = frame
                }
                .overlay(alignment: .topLeading) {
                    if moodChipFrame.width > 1 {
                        MoodChipHitMenu(viewModel: moodButtonViewModel, width: moodChipFrame.width)
                            .offset(
                                x: moodChipFrame.minX,
                                y: moodChipFrame.midY - MoodButton.minimumHitLength / 2
                            )
                    }
                }
        }
    }

    private func expandedStack(forMeasurement: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            completionRateSection
            Divider()
            ratingRow(forMeasurement: forMeasurement)
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
                Text("\(displayCompleted)/\(displayTotal)개  \(displayRate.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            ProgressView(value: displayRate)
                .tint(AppTheme.shared.accent)
                .scaleEffect(y: 1.4)
        }
    }

    // MARK: - 별점 행

    private func ratingRow(forMeasurement: Bool) -> some View {
        RatingMoodRowLayout {
            Text("별점")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .leading)

            FittingPawRating(rating: currentRatingCount) { count in
                let tapped = DayRating.allCases[count - 1]
                let newRating: DayRating? = (viewModel.selectedRating == tapped) ? nil : tapped
                Task { await viewModel.selectRating(newRating) }
            }

            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 8)
                } else {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
            }

            MoodButton(
                date: date,
                forMeasurement: forMeasurement,
                viewModel: moodButtonViewModel
            )
        }
    }

    private var showsMoodChip: Bool {
        _ = MoodService.shared.revision
        let plannerId = PlannerService.shared.selectedPlannerId
        guard !plannerId.isEmpty,
              let planner = PlannerService.shared.store.first(where: { $0.id == plannerId }) else {
            return false
        }
        return planner.decodedReportPropsMapping.moodMode != .disabled
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

