import Foundation
import Darwin
import Testing
@testable import MakeRun

struct TerminalScriptBuilderTests {
    @Test func loginBashRunCapturesOutputAndRealExitCode() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeRunShellTests-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("Project's Folder", isDirectory: true)
        let fakeHome = root.appendingPathComponent("Home", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "export MAKE_RUN_PROFILE_MARKER=profile-loaded\nsource \"$HOME/.bashrc\"\n".write(
            to: fakeHome.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)
        try "export MAKE_RUN_RC_MARKER=rc-loaded\n".write(
            to: fakeHome.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
        try """
        verify:
        \t@printf '%s %s\\n' "$$MAKE_RUN_PROFILE_MARKER" "$$MAKE_RUN_RC_MARKER"

        fail:
        \t@echo expected failure
        \t@false
        """.write(to: project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let success = try execute(target: "verify", project: project, home: fakeHome, root: root)
        #expect(success.code == 0)
        #expect(success.status == "0")
        #expect(success.log.contains("profile-loaded rc-loaded"))
        #expect(success.log.contains("Make Run finished with exit code 0"))

        let failure = try execute(target: "fail", project: project, home: fakeHome, root: root)
        #expect(failure.code != 0)
        #expect(failure.status != "0")
        #expect(failure.log.contains("expected failure"))
    }

    @Test func loginShellDoesNotForceSourceARecursiveBashRC() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeRunRecursiveRCTests-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("Project", isDirectory: true)
        let fakeHome = root.appendingPathComponent("Home", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "export MAKE_RUN_PROFILE_MARKER=profile-loaded\n".write(
            to: fakeHome.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)
        try "source \"$HOME/.bashrc\"\n".write(
            to: fakeHome.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
        try """
        verify:
        \t@printf '%s\\n' "$$MAKE_RUN_PROFILE_MARKER"
        """.write(to: project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let result = try execute(target: "verify", project: project, home: fakeHome, root: root)
        #expect(result.code == 0)
        #expect(result.status == "0")
        #expect(result.log.contains("profile-loaded"))
    }

    @Test func terminatedLauncherWritesACompletionStatus() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeRunSignalTests-\(UUID().uuidString)", isDirectory: true)
        let project = root.appendingPathComponent("Project", isDirectory: true)
        let fakeHome = root.appendingPathComponent("Home", isDirectory: true)
        let run = root.appendingPathComponent("Run", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fakeHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: run, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "wait:\n\t@sleep 2\n".write(
            to: project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
        let log = run.appendingPathComponent("output.log")
        let status = run.appendingPathComponent("exit-code")
        let script = run.appendingPathComponent("run.command")
        try TerminalScriptBuilder.build(
            projectDirectory: project.path,
            targetName: "wait",
            logPath: log.path,
            statusPath: status.path,
            header: "Header\n"
        ).write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = ProcessInfo.processInfo.environment.merging(["HOME": fakeHome.path]) { _, new in new }
        try process.run()

        let pidPath = TerminalScriptBuilder.launcherPIDPath(forStatusPath: status.path)
        let deadline = Date().addingTimeInterval(1)
        while !FileManager.default.fileExists(atPath: pidPath), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(FileManager.default.fileExists(atPath: pidPath))
        Darwin.kill(process.processIdentifier, SIGTERM)
        process.waitUntilExit()

        #expect(try String(contentsOf: status, encoding: .utf8) == "143")
        #expect(try String(contentsOf: log, encoding: .utf8).contains("exit code 143"))
    }

    private func execute(target: String, project: URL, home: URL, root: URL) throws
        -> (code: Int32, status: String, log: String)
    {
        let run = root.appendingPathComponent(target, isDirectory: true)
        try FileManager.default.createDirectory(at: run, withIntermediateDirectories: true)
        let log = run.appendingPathComponent("output.log")
        let status = run.appendingPathComponent("exit-code")
        let script = run.appendingPathComponent("run.command")
        try TerminalScriptBuilder.build(
            projectDirectory: project.path,
            targetName: target,
            logPath: log.path,
            statusPath: status.path,
            header: "Header\n"
        ).write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = ProcessInfo.processInfo.environment.merging(["HOME": home.path]) { _, new in new }
        try process.run()
        process.waitUntilExit()
        let pidPath = TerminalScriptBuilder.launcherPIDPath(forStatusPath: status.path)
        #expect(FileManager.default.fileExists(atPath: pidPath))
        return (
            process.terminationStatus,
            try String(contentsOf: status, encoding: .utf8),
            try String(contentsOf: log, encoding: .utf8)
        )
    }
}
