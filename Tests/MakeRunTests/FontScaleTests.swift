import Foundation
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
}
