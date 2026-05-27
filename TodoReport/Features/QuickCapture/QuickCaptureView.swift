import SwiftUI

struct QuickCaptureView: View {
    @State private var viewModel = QuickCaptureViewModel()
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String?, String?, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AutoFocusTextField(text: $viewModel.title, placeholder: "할일")
                        .frame(height: 44)

                    TextField("메모", text: $viewModel.memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Picker("카테고리", selection: $viewModel.selectedCategoryId) {
                        Text("없음").tag(Optional<String>.none)
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)

                    Button {
                        withAnimation { viewModel.showDatePicker.toggle() }
                    } label: {
                        HStack {
                            Text("날짜").foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if viewModel.showDatePicker {
                        DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                }

                Section {
                    Button {
                        viewModel.showProAlert = true
                    } label: {
                        HStack {
                            Text("반복 설정").foregroundStyle(.primary)
                            Spacer()
                            Text("🔒 Pro").foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("할일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소", role: .cancel) { dismiss() }
                        .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let memo = viewModel.memo.trimmingCharacters(in: .whitespaces)
                        onSave(
                            viewModel.title.trimmingCharacters(in: .whitespaces),
                            memo.isEmpty ? nil : memo,
                            viewModel.selectedCategoryId,
                            viewModel.selectedDate
                        )
                        dismiss()
                    }
                    .disabled(!viewModel.isSaveEnabled)
                    .tint(viewModel.isSaveEnabled ? Color.nockOrange : Color(.tertiaryLabel))
                    .fontWeight(.semibold)
                }
            }
            .alert("Pro 기능", isPresented: $viewModel.showProAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("반복 투두는 Pro 구독 기능입니다.")
            }
        }
        .presentationDetents([.large])
    }
}

private struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 20, weight: .medium)
        tf.delegate = context.coordinator
        tf.becomeFirstResponder()
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
            if let cur = tf.text, let r = Range(range, in: cur) {
                text = cur.replacingCharacters(in: r, with: s)
            }
            return true
        }
    }
}
