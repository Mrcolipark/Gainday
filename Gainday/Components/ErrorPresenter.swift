import SwiftUI

/// 全局错误管理器 - 用于显示 Toast 和 Alert
@Observable
class ErrorPresenter {
    static let shared = ErrorPresenter()

    var currentToast: ToastMessage?
    var currentAlert: AlertMessage?

    private init() {}

    // MARK: - Toast (短暂提示)

    struct ToastMessage: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastType
        let duration: TimeInterval

        enum ToastType {
            case error
            case warning
            case success
            case info

            var color: Color {
                switch self {
                case .error:   return .red
                case .warning: return .orange
                case .success: return .green
                case .info:    return .blue
                }
            }

            var icon: String {
                switch self {
                case .error:   return "xmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .success: return "checkmark.circle.fill"
                case .info:    return "info.circle.fill"
                }
            }
        }

        static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
            lhs.id == rhs.id
        }
    }

    func showToast(_ message: String, type: ToastMessage.ToastType = .error, duration: TimeInterval = 3.0) {
        Task { @MainActor in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentToast = ToastMessage(message: message, type: type, duration: duration)
            }

            try? await Task.sleep(for: .seconds(duration))

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if currentToast?.message == message {
                    currentToast = nil
                }
            }
        }
    }

    func showError(_ error: Error) {
        showToast(error.localizedDescription, type: .error)
    }

    func showNetworkError() {
        showToast("网络连接失败，请检查网络设置", type: .error)
    }

    func showSuccess(_ message: String) {
        showToast(message, type: .success, duration: 2.0)
    }

    // MARK: - Alert (需要确认的对话框)

    struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryButton: String
        let primaryAction: () -> Void
        let secondaryButton: String?
        let secondaryAction: (() -> Void)?
    }

    func showAlert(
        title: String,
        message: String,
        primaryButton: String = "确定",
        primaryAction: @escaping () -> Void = {},
        secondaryButton: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        Task { @MainActor in
            currentAlert = AlertMessage(
                title: title,
                message: message,
                primaryButton: primaryButton,
                primaryAction: primaryAction,
                secondaryButton: secondaryButton,
                secondaryAction: secondaryAction
            )
        }
    }

    func dismissAlert() {
        currentAlert = nil
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ErrorPresenter.ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.type.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(toast.type.color)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(toast.type.color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - View Modifier for Toast

struct ToastModifier: ViewModifier {
    @State private var errorPresenter = ErrorPresenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = errorPresenter.currentToast {
                    ToastView(toast: toast)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .alert(
                errorPresenter.currentAlert?.title ?? "",
                isPresented: Binding(
                    get: { errorPresenter.currentAlert != nil },
                    set: { if !$0 { errorPresenter.dismissAlert() } }
                )
            ) {
                if let alert = errorPresenter.currentAlert {
                    Button(alert.primaryButton) {
                        alert.primaryAction()
                        errorPresenter.dismissAlert()
                    }
                    if let secondary = alert.secondaryButton {
                        Button(secondary, role: .cancel) {
                            alert.secondaryAction?()
                            errorPresenter.dismissAlert()
                        }
                    }
                }
            } message: {
                if let alert = errorPresenter.currentAlert {
                    Text(alert.message)
                }
            }
    }
}

extension View {
    func withErrorPresenter() -> some View {
        modifier(ToastModifier())
    }
}

#Preview {
    VStack {
        Button("Show Error") {
            ErrorPresenter.shared.showToast("加载数据失败", type: .error)
        }
        Button("Show Success") {
            ErrorPresenter.shared.showSuccess("保存成功")
        }
        Button("Show Warning") {
            ErrorPresenter.shared.showToast("网络不稳定", type: .warning)
        }
    }
    .withErrorPresenter()
}
