import Foundation
import Testing
@testable import MakeRun

struct RunDurationTests {
    @Test func completedRunDurationIsFrozenAtCompletion() {
        let start = Date(timeIntervalSince1970: 1_000)
        let completion = start.addingTimeInterval(18)
        let run = makeRun(startedAt: start, completedAt: completion, state: .succeeded)

        #expect(run.elapsed(at: start.addingTimeInterval(500)) == 18)
        #expect(RunDurationFormatter.string(for: run.elapsed(at: start.addingTimeInterval(500))) == "18 sec")
    }

    @Test func runningDurationUsesCurrentTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        let run = makeRun(startedAt: start, completedAt: nil, state: .running)

        #expect(run.elapsed(at: start.addingTimeInterval(84)) == 84)
        #expect(RunDurationFormatter.string(for: 84) == "1 min 24 sec")
        #expect(RunDurationFormatter.string(for: 3_725) == "1 hr 2 min")
    }

    private func makeRun(startedAt: Date, completedAt: Date?, state: RunState) -> RunRecord {
        RunRecord(
            id: UUID(),
            projectID: UUID(),
            targetID: UUID(),
            projectName: "Project",
            targetName: "target",
            startedAt: startedAt,
            completedAt: completedAt,
            state: state,
            exitCode: state == .running ? nil : 0,
            logPath: "/tmp/log",
            statusPath: "/tmp/status",
            isRead: true
        )
    }
}
