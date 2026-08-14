import Foundation
import Testing
@testable import MakeRun

struct KeyboardNavigationTests {
    @MainActor
    @Test func projectSearchAcceptsSlashPrefixAndSelectsFirstNameMatch() {
        let store = AppStore(monitorRuns: false)
        let calories = MakeProject(
            name: "Calories",
            directoryPath: "/tmp/calories",
            makefilePath: "/tmp/calories/Makefile"
        )
        let calendar = MakeProject(
            name: "Calendar",
            directoryPath: "/tmp/calendar",
            makefilePath: "/tmp/calendar/Makefile"
        )
        store.projects = [calendar, calories]
        store.selectedProjectID = nil
        store.projectSearchText = "/cal"

        store.selectFirstProjectMatchingSearch()

        #expect(store.projectSearchQuery == "cal")
        #expect(store.matchingProjects.map(\.name) == ["Calendar", "Calories"])
        #expect(store.selectedProjectID == calendar.id)
    }

    @MainActor
    @Test func clearingProjectSearchKeepsTheSelectedProject() {
        let first = MakeProject(
            name: "Alpha",
            directoryPath: "/tmp/alpha",
            makefilePath: "/tmp/alpha/Makefile"
        )
        let second = MakeProject(
            name: "Calories",
            directoryPath: "/tmp/calories",
            makefilePath: "/tmp/calories/Makefile"
        )
        let store = AppStore(monitorRuns: false)
        store.projects = [first, second]
        store.selectedProjectID = second.id
        store.projectSearchText = "/cal"
        store.selectFirstProjectMatchingSearch()

        store.dismissProjectSearch()
        store.selectFirstProjectMatchingSearch()

        #expect(store.projectSearchText.isEmpty)
        #expect(store.projectSearchDismissRequest == 1)
        #expect(store.selectedProjectID == second.id)
    }

    @MainActor
    @Test func quickTargetShortcutsFollowSidebarOrder() {
        let first = MakeTarget(name: "build", isFavorite: true)
        let second = MakeTarget(name: "test", isFavorite: true)
        let project = MakeProject(
            name: "Example",
            directoryPath: "/tmp/example",
            makefilePath: "/tmp/example/Makefile",
            targets: [first, second]
        )
        let store = AppStore(monitorRuns: false)

        #expect(store.quickTarget(at: 0, for: project)?.id == first.id)
        #expect(store.quickTarget(at: 1, for: project)?.id == second.id)
        #expect(store.quickTarget(at: 3, for: project) == nil)
    }
}
