import AppKit
import Foundation
import SwiftUI
import Testing
@testable import MakeRun

struct FontScaleTests {
    @MainActor
    @Test func fontScaleClampsWithoutRecursiveSetterReentry() {
        let suiteName = "MakeRunTests.FontScale.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = AppStore(preferences: preferences, monitorRuns: false)

        store.fontScale = 10
        #expect(store.fontScale == 1.4)
        #expect(preferences.double(forKey: "fontScale") == 1.4)

        for _ in 0..<20 { store.decreaseFontScale() }
        #expect(store.fontScale == 0.8)

        for _ in 0..<20 { store.increaseFontScale() }
        #expect(store.fontScale == 1.4)

        store.resetFontScale()
        #expect(store.fontScale == 1)
    }

    @Test func fontScaleMapsAcrossAppWidePointSizes() {
        #expect(AppTypography.pointSize(.body, scale: 0.8) == 10.4)
        #expect(AppTypography.pointSize(.body, scale: 1.0) == 13)
        #expect(AppTypography.pointSize(.body, scale: 1.4) == 18.2)
        #expect(AppTypography.quickActionControlSize(for: 1.0) == .mini)
        #expect(AppTypography.quickActionControlSize(for: 1.4) == .small)
    }

    @MainActor
    @Test func fontScaleChangesActualRenderedTextBounds() {
        let small = renderedSize(scale: 0.8)
        let large = renderedSize(scale: 1.4)

        #expect(large.width > small.width * 1.5)
        #expect(large.height > small.height * 1.5)
    }

    @MainActor
    private func renderedSize(scale: Double) -> NSSize {
        let view = NSHostingView(rootView: VStack(alignment: .leading) {
            Text("Favorites").appFont(.subheadline, weight: .semibold)
            Text("calorie-tracker").appFont(.body, weight: .medium)
            Label("phone-deploy", systemImage: "play.fill").appFont(.caption)
            Text("No description available").appFont(.caption)
            LabeledContent("Directory", value: "/Users/example/project")
        }
        .appFont(.body)
        .environment(\.fontScale, scale))
        view.layoutSubtreeIfNeeded()
        return view.fittingSize
    }
}
