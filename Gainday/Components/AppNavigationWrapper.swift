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
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
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

// MARK: - View Modifier variant

struct AppNavigationModifier: ViewModifier {
    let title: String
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

extension View {
    func appNavigation(title: String) -> some View {
        modifier(AppNavigationModifier(title: title))
    }
}
