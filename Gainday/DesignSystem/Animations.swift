import SwiftUI

enum AppAnimations {
    static let cardPress = Animation.snappy(duration: 0.15)
    static let numberTransition = Animation.snappy
    static let colorChange = Animation.easeInOut(duration: 0.3)

    static func staggeredEntry(index: Int) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
        .delay(Double(index) * 0.05)
    }

    static let sheetPresent = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let pageSwipe = Animation.easeInOut(duration: 0.25)

    // MARK: - Heatmap Cell Animation

    static func heatmapCellAppear(row: Int, col: Int) -> Animation {
        .spring(response: 0.35, dampingFraction: 0.7)
        .delay(Double(row + col) * 0.03)
    }

    // MARK: - Expand/Collapse Animation

    static let expandCollapse = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Staggered List Modifier

struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : 30)
            .onAppear {
                withAnimation(AppAnimations.staggeredEntry(index: index)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }
}

// MARK: - Heatmap Cell Appearance Modifier

struct HeatmapCellAppearance: ViewModifier {
    let row: Int
    let col: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(AppAnimations.heatmapCellAppear(row: row, col: col)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func heatmapCellAppearance(row: Int, col: Int) -> some View {
        modifier(HeatmapCellAppearance(row: row, col: col))
    }
}
