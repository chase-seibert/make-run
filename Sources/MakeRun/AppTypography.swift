import SwiftUI

enum AppTextStyle: Sendable {
    case largeTitle
    case title
    case headline
    case body
    case subheadline
    case caption
    case caption2

    var basePointSize: CGFloat {
        switch self {
        case .largeTitle: 26
        case .title: 20
        case .headline: 13
        case .body: 13
        case .subheadline: 11
        case .caption: 10
        case .caption2: 9
        }
    }
}

enum AppTypography {
    static func pointSize(_ style: AppTextStyle, scale: Double) -> CGFloat {
        style.basePointSize * CGFloat(min(max(scale, 0.8), 1.4))
    }

    static func font(
        _ style: AppTextStyle,
        scale: Double,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        .system(size: pointSize(style, scale: scale), weight: weight, design: design)
    }

    static func quickActionControlSize(for scale: Double) -> ControlSize {
        scale >= 1.2 ? .small : .mini
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.fontScale) private var scale
    let style: AppTextStyle
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(AppTypography.font(style, scale: scale, weight: weight, design: design))
    }
}

extension View {
    func appFont(
        _ style: AppTextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(AppFontModifier(style: style, weight: weight, design: design))
    }
}
