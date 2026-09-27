import SwiftUI

struct PlannerDowngradeView: View {
    @State private var viewModel = PlannerDowngradeViewModel()
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Pro 구독이 종료되었습니다")
                        .font(.title2.bold())
                    Text("유지할 플래너 1개를 선택해 주세요.\n나머지 플래너는 비활성화되며, Pro 구독 시 다시 사용할 수 있어요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                List(viewModel.planners) { planner in
                    HStack {
                        PlannerIconView(
                            iconType: planner.iconType,
                            iconImageData: planner.iconImageData,
                            colorHex: planner.colorHex,
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planner.name)
                                .font(.body)
                            if planner.isNotionConnected {
                                Text("Notion 연동")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.selectedPlannerId == planner.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.nockOrange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedPlannerId = planner.id }
                }
                .listStyle(.insetGrouped)

                Button {
                    viewModel.confirmDowngrade()
                } label: {
                    Text("확인")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.nockOrange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(viewModel.selectedPlannerId.isEmpty)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .interactiveDismissDisabled()
            .onChange(of: viewModel.isConfirmed) { _, confirmed in
                if confirmed { onDismiss() }
            }
        }
        .onAppear { viewModel.load() }
    }
}
