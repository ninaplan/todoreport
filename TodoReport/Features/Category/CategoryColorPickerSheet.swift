import SwiftUI
import UIKit

/// 커스텀 「＋ 추가」용 iOS 색 고르기 창.
/// SwiftUI `ColorPicker`는 고르는 동안 값이 계속 바뀌고 "닫음" 신호가 없어 중간 색까지 들어갈 수 있다 →
/// UIKit 창을 써서 고른 마지막 색만 넘기고, 닫을 때(완료·쓸어내리기) 부르는 쪽이 한 번 저장한다.
struct CategoryColorPickerSheet: UIViewControllerRepresentable {
    /// 고르는 중인 색 (hex). 닫힐 때 부르는 쪽이 이 값을 커스텀에 넣는다
    let onPick: (String) -> Void
    let onFinish: () -> Void
    /// 처음 보여 줄 색 (nil이면 iOS 기본)
    var initialHex: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        if let initialHex {
            picker.selectedColor = UIColor(Color(hex: initialHex))
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let onPick: (String) -> Void
        let onFinish: () -> Void

        init(onPick: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
            self.onPick = onPick
            self.onFinish = onFinish
        }

        func colorPickerViewController(
            _ viewController: UIColorPickerViewController,
            didSelect color: UIColor,
            continuously: Bool
        ) {
            onPick(Color(uiColor: color).hexString)
        }

        /// 창의 ✕(완료)를 눌렀을 때
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            onFinish()
        }
    }
}
