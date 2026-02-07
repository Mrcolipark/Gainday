import SwiftUI
import UIKit

// MARK: - 禁用导航返回手势

extension View {
    /// 在条件满足时禁用导航的滑动返回手势
    func disableSwipeBack(when condition: Bool) -> some View {
        background(
            DisableSwipeBackView(isDisabled: condition)
        )
    }
}

private struct DisableSwipeBackView: UIViewControllerRepresentable {
    let isDisabled: Bool

    func makeUIViewController(context: Context) -> DisableSwipeBackViewController {
        DisableSwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: DisableSwipeBackViewController, context: Context) {
        uiViewController.setSwipeBackEnabled(!isDisabled)
    }
}

private class DisableSwipeBackViewController: UIViewController {
    private weak var cachedNavController: UINavigationController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cachedNavController = findNavController()
    }

    func setSwipeBackEnabled(_ enabled: Bool) {
        // 延迟执行确保导航控制器已经设置好
        DispatchQueue.main.async { [weak self] in
            if self?.cachedNavController == nil {
                self?.cachedNavController = self?.findNavController()
            }
            self?.cachedNavController?.interactivePopGestureRecognizer?.isEnabled = enabled
        }
    }

    private func findNavController() -> UINavigationController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let nav = nextResponder as? UINavigationController {
                return nav
            }
            responder = nextResponder
        }
        return nil
    }
}
