import SwiftUI

// MARK: - Empty State View

/// 统一的空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(Color.blue)
                        }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Loading State View

/// 统一的加载状态视图
struct LoadingStateView: View {
    let message: String

    init(_ message: String = "加载中...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Error State View

/// 统一的错误状态视图
struct ErrorStateView: View {
    let error: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("加载失败")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .strokeBorder(Color.blue, lineWidth: 1.5)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - State Container

/// 通用状态容器 - 处理 loading/error/empty/content 状态
struct StateContainer<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool
    let emptyConfig: EmptyConfig?
    let retryAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    struct EmptyConfig {
        let icon: String
        let title: String
        let message: String
        var actionTitle: String?
        var action: (() -> Void)?
    }

    init(
        isLoading: Bool,
        error: String? = nil,
        isEmpty: Bool = false,
        emptyConfig: EmptyConfig? = nil,
        retryAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.isEmpty = isEmpty
        self.emptyConfig = emptyConfig
        self.retryAction = retryAction
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView()
            } else if let error = error {
                ErrorStateView(error: error, retryAction: retryAction)
            } else if isEmpty, let config = emptyConfig {
                EmptyStateView(
                    icon: config.icon,
                    title: config.title,
                    message: config.message,
                    actionTitle: config.actionTitle,
                    action: config.action
                )
            } else {
                content()
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "chart.bar.xaxis",
        title: "暂无持仓",
        message: "点击下方按钮添加您的第一个持仓",
        actionTitle: "添加持仓"
    ) {
        print("Add holding")
    }
}

#Preview("Loading State") {
    LoadingStateView("正在加载行情...")
}

#Preview("Error State") {
    ErrorStateView(error: "网络连接失败，请检查网络设置") {
        print("Retry")
    }
}
