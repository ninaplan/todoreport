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
    /// 그날 집중 시간(분). nil이면 줄을 안 보인다 (Pro가 아니거나 완료한 블록이 없는 날).
    /// 하루 리포트 모듈은 타임블록을 직접 읽지 않고 이 숫자만 받는다 (모듈 독립)
    var focusMinutes: Int? = nil

    @State private var isExpanded = false
    @State private var lastAppliedExpandToken = 0
    @State private var expandedContentHeight: CGFloat = 0
    @FocusState private var isReviewFocused: Bool
    @State private var showRatingLabelEditor = false
    @State private var showRatingLabelHint = false
    @AppStorage("hasSeenRatingLabelHint") private var hasSeenRatingLabelHint = false

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
        .onAppear {
            onFirstAppear?()
            applyExpandTokenIfNeeded()
        }
        .onChange(of: expandToken) { _, _ in
            applyExpandTokenIfNeeded()
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded else { return }
            presentRatingLabelHintIfNeeded()
        }
        .sheet(isPresented: $showRatingLabelEditor) {
            if let plannerId = PlannerService.shared.selectedPlanner?.id {
                NavigationStack {
                    RatingLabelEditView(plannerId: plannerId, presentsAsSheet: true)
                }
                .presentationDetents([.medium])
            }
        }
    }

    /// 카드를 처음 펼쳤을 때 1회 「글자를 탭하면 이름을 바꿀 수 있습니다」
    private func presentRatingLabelHintIfNeeded() {
        guard !hasSeenRatingLabelHint else { return }
        hasSeenRatingLabelHint = true
        Task {
            // 펼침 애니메이션이 끝난 뒤 띄운다
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run { showRatingLabelHint = true }
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { showRatingLabelHint = false }
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

    private func expandedContent(forMeasurement: Bool) -> some View {
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
            // 그날 집중 시간 (Pro이고 완료한 블록이 있을 때만)
            if let focusMinutes, focusMinutes > 0 {
                HStack {
                    Text("집중 시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: Self.focusText(focusMinutes))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.top, 4)
            }
        }
    }

    /// 11h48m / 분이 0이면 11h / 1시간 미만이면 45m (리포트 탭 집중 시간과 같은 규칙. 모듈을 나누려고 여기 따로 둠)
    private static func focusText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h\(rest)m"
    }

    // MARK: - 별점 행

    private func ratingRow(forMeasurement: Bool) -> some View {
        HStack(spacing: 0) {
            ratingLabelButton(forMeasurement: forMeasurement)

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

    /// 「별점」(또는 사용자가 정한 이름) 글자. 탭하면 이름 바꾸기 시트
    @ViewBuilder
    private func ratingLabelButton(forMeasurement: Bool) -> some View {
        let isReadOnly = PlannerService.shared.selectedPlanner?.isReadOnly ?? false
        let button = Button {
            showRatingLabelHint = false
            showRatingLabelEditor = true
        } label: {
            Text(verbatim: RatingLabel.title(RatingLabel.current))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                // 기본 「별점」은 예전과 같은 44pt 칸. 긴 이름일 때만 발바닥과 4pt 띄움
                .padding(.trailing, 4)
                .frame(minWidth: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .accessibilityHint(Text("별점 이름 바꾸기"))

        // 측정용(숨긴 복사본)에는 말풍선을 붙이지 않는다 — 두 번 뜨는 것 방지
        if forMeasurement {
            button
        } else {
            button.popover(isPresented: $showRatingLabelHint, arrowEdge: .bottom) {
                Text("글자를 탭하면 이름을 바꿀 수 있습니다")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .presentationCompactAdaptation(.popover)
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

