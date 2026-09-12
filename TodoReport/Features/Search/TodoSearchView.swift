import SwiftUI

struct TodoSearchView: View {
    @State private var viewModel = TodoSearchViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        Group {
            if vm.trimmedQuery.isEmpty {
                ContentUnavailableView(
                    "할일 검색",
                    systemImage: "magnifyingglass",
                    description: Text("제목과 메모에서 찾습니다.")
                )
            } else if vm.results.isEmpty {
                ContentUnavailableView.search(text: vm.trimmedQuery)
            } else {
                List {
                    ForEach(vm.results) { todo in
                        Button {
                            viewModel.openResult(todo)
                        } label: {
                            SearchResultRow(
                                todo: todo,
                                plannerName: viewModel.plannerName(for: todo)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("검색")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.query, prompt: Text("할일 검색"))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("노션에 연결된 할일은 이 기기에 동기화된 기간만 검색됩니다.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
    }
}
