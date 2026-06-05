import SwiftUI

struct PersistenceErrorView: View {
    let error: Error

    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("데이터를 불러올 수 없습니다")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("앱 저장소를 여는 데 실패했습니다.\n앱을 완전히 종료한 뒤 다시 실행해 주세요.\n문제가 계속되면 개발팀에 문의해 주세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("앱 종료") {
                exit(0)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            Button(showDetail ? "오류 상세 숨기기" : "오류 상세 보기") {
                showDetail.toggle()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if showDetail {
                ScrollView {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxHeight: 160)
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }
}
