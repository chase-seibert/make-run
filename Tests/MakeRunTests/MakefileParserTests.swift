import Foundation
import Testing
@testable import MakeRun

struct MakefileParserTests {
    @Test func parsesTargetsAndDescriptions() {
        let makefile = """
        # Build the application bundle.
        build: compile

        test: ## Run the complete test suite
        \t@swift test

        lint format: dependencies
        \t@echo done

        VARIABLE := not-a-target
        %.o: %.c
        .PHONY: build test
        """

        let targets = MakefileParser.parseTargets(from: makefile)
        #expect(targets.map(\.name) == ["build", "test", "lint", "format"])
        #expect(targets.first(where: { $0.name == "build" })?.targetDescription == "Build the application bundle.")
        #expect(targets.first(where: { $0.name == "test" })?.targetDescription == "Run the complete test suite")
    }

    @Test func parsesCommonHelpFormatsAndAnsiColor() {
        let output = """
          build       Build the app
          test: Run tests
          clean - Remove products
          \u{001B}[32mdeploy\u{001B}[0m      Deploy the app
        """

        let descriptions = MakefileParser.parseHelpOutput(output)
        #expect(descriptions["build"] == "Build the app")
        #expect(descriptions["test"] == "Run tests")
        #expect(descriptions["clean"] == "Remove products")
        #expect(descriptions["deploy"] == "Deploy the app")
    }

    @Test func recursivelyDiscoversProjectsAndUsesHelpFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeRunTests-\(UUID().uuidString)", isDirectory: true)
        let project = root
            .appendingPathComponent("Organization", isDirectory: true)
            .appendingPathComponent("Team", isDirectory: true)
            .appendingPathComponent("Example Project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let makefile = """
        build:
        \t@echo building

        help:
        \t@printf 'build  Build from help output\\n'
        """
        try makefile.write(to: project.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let discovered = MakefileParser.discoverProjects(in: [root.path])
        #expect(discovered.count == 1)
        #expect(discovered.first?.name == "Example Project")
        #expect(discovered.first?.targets.first(where: { $0.name == "build" })?.targetDescription == "Build from help output")
    }
}
