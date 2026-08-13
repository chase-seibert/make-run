import Darwin
import Foundation
import Testing
@testable import MakeRun

struct BackgroundProcessRunnerTests {
    @Test func loginBashRunCapturesOutputAndRealExitCode() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "export MAKE_RUN_PROFILE_MARKER=profile-loaded\nsource \"$HOME/.bashrc\"\n".write(
            to: fixture.home.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)
        try "export MAKE_RUN_RC_MARKER=rc-loaded\n".write(
            to: fixture.home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
        try """
        verify:
        \t@printf '%s %s\\n' "$$MAKE_RUN_PROFILE_MARKER" "$$MAKE_RUN_RC_MARKER"

        fail:
        \t@echo expected failure
        \t@false
        """.write(to: fixture.project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let success = try fixture.execute(target: "verify")
        #expect(success.code == 0)
        #expect(success.status == "0")
        #expect(success.log.contains("profile-loaded rc-loaded"))
        #expect(success.log.contains("Make Run finished with exit code 0"))

        let failure = try fixture.execute(target: "fail")
        #expect(failure.code != 0)
        #expect(failure.status != "0")
        #expect(failure.log.contains("expected failure"))
    }

    @Test func loginShellDoesNotForceSourceARecursiveBashRC() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "export MAKE_RUN_PROFILE_MARKER=profile-loaded\n".write(
            to: fixture.home.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)
        try "source \"$HOME/.bashrc\"\n".write(
            to: fixture.home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
        try "verify:\n\t@printf '%s\\n' \"$$MAKE_RUN_PROFILE_MARKER\"\n".write(
            to: fixture.project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let result = try fixture.execute(target: "verify")
        #expect(result.code == 0)
        #expect(result.log.contains("profile-loaded"))
    }

    @Test func terminatedBackgroundProcessWritesACompletionStatus() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try "wait:\n\t@sleep 2\n".write(
            to: fixture.project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
        let launch = try fixture.prepare(target: "wait")
        try launch.process.run()
        Thread.sleep(forTimeInterval: 0.05)
        Darwin.kill(launch.process.processIdentifier, SIGTERM)
        launch.process.waitUntilExit()
        try launch.logHandle.close()

        #expect(try String(contentsOf: fixture.statusURL, encoding: .utf8) == "143")
        #expect(try String(contentsOf: fixture.logURL, encoding: .utf8).contains("exit code 143"))
    }

    private final class Fixture {
        let root: URL
        let project: URL
        let home: URL
        let run: URL
        var logURL: URL { run.appendingPathComponent("output.log") }
        var statusURL: URL { run.appendingPathComponent("exit-code") }

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("MakeRunBackgroundTests-\(UUID().uuidString)", isDirectory: true)
            project = root.appendingPathComponent("Project's Folder", isDirectory: true)
            home = root.appendingPathComponent("Home", isDirectory: true)
            run = root.appendingPathComponent("Run", isDirectory: true)
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: run, withIntermediateDirectories: true)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }

        func prepare(target: String) throws -> BackgroundProcessLaunch {
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: statusURL)
            return try BackgroundProcessRunner.prepare(
                projectDirectory: project.path,
                targetName: target,
                logPath: logURL.path,
                statusPath: statusURL.path,
                header: "Header\n",
                environment: ProcessInfo.processInfo.environment.merging(["HOME": home.path]) { _, new in new }
            )
        }

        func execute(target: String) throws -> (code: Int32, status: String, log: String) {
            let launch = try prepare(target: target)
            try launch.process.run()
            launch.process.waitUntilExit()
            try launch.logHandle.close()
            return (
                launch.process.terminationStatus,
                try String(contentsOf: statusURL, encoding: .utf8),
                try String(contentsOf: logURL, encoding: .utf8)
            )
        }
    }
}
