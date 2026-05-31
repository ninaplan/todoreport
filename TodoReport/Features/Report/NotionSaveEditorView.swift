import SwiftUI

struct NotionSaveEditorView: View {
    let periodTitle: String
    let period: DateInterval
    let completionRate: Double
    let avgRating: Double
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var comment: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsSection
                    commentSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("노션에 저장하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onConfirm(comment)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(AppTheme.shared.accent)
                }
            }
        }
    }

    // MARK: - 기간 통계

    private var statsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(periodTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 0) {
                statItem(
                    value: "\(Int(completionRate * 100))%",
                    label: "평균 완료율",
                    color: AppTheme.shared.accent
                )
                Divider().frame(height: 40)
                statItem(
                    value: ratingLabel,
                    label: "별점 평균",
                    color: .primary
                )
            }
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratingLabel: String {
        guard avgRating > 0 else { return "—" }
        return String(format: "%.1f", avgRating)
    }

    // MARK: - 한마디 입력

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("한마디")
                .font(.subheadline.bold())

            ZStack(alignment: .topLeading) {
                TextEditor(text: $comment)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)

                if comment.isEmpty {
                    Text("이번 기간을 정리하는 한마디를 적어보세요")
                        .font(.subheadline)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
