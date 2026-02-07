import SwiftUI

struct AppNavigationWrapper<Content: View>: View {
    let title: String
    let content: Content
    @State private var showSettings = false

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .toolbarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
    }
}

// MARK: - 统一导航栏样式修饰符

struct UnifiedNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    /// 应用统一的导航栏样式（背景色与主内容一致）
    func unifiedNavigationStyle() -> some View {
        modifier(UnifiedNavigationStyle())
    }
}
