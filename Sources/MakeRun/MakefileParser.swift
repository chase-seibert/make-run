import Foundation

enum MakefileParser {
    private static let makefileNames = ["GNUmakefile", "Makefile", "makefile"]
    private static let ignoredDirectories: Set<String> = [
        ".git", ".svn", ".hg", ".build", ".swiftpm", "build", "DerivedData", "node_modules", "Pods"
    ]

    static func discoverProjects(in roots: [String], includeHelpDescriptions: Bool = true) -> [DiscoveredProject] {
        var makefilesByDirectory: [String: URL] = [:]
        let manager = FileManager.default

        for rootPath in roots {
            let root = URL(fileURLWithPath: rootPath).standardizedFileURL
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                if values?.isDirectory == true, ignoredDirectories.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                guard values?.isRegularFile == true, makefileNames.contains(url.lastPathComponent) else { continue }
                let directory = url.deletingLastPathComponent().standardizedFileURL.path
                let current = makefilesByDirectory[directory]
                if current == nil || priority(of: url.lastPathComponent) < priority(of: current!.lastPathComponent) {
                    makefilesByDirectory[directory] = url
                }
            }

            for candidate in makefileNames {
                let direct = root.appendingPathComponent(candidate)
                if manager.fileExists(atPath: direct.path) {
                    makefilesByDirectory[root.path] = direct
                    break
                }
            }
        }

        return makefilesByDirectory.map { directory, makefile in
            let text = (try? String(contentsOf: makefile, encoding: .utf8)) ?? ""
            var targets = parseTargets(from: text)
            if includeHelpDescriptions, targets.contains(where: { $0.name == "help" }) {
                let help = runHelp(in: URL(fileURLWithPath: directory))
                let helpDescriptions = parseHelpOutput(help)
                targets = targets.map { target in
                    var copy = target
                    if copy.targetDescription == "No description available",
                       let description = helpDescriptions[copy.name] {
                        copy.targetDescription = description
                    }
                    return copy
                }
            }
            return DiscoveredProject(
                name: URL(fileURLWithPath: directory).lastPathComponent,
                directoryPath: directory,
                makefilePath: makefile.path,
                targets: targets
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func enrichHelpDescriptions(in projects: [DiscoveredProject]) -> [DiscoveredProject] {
        projects.map { project in
            guard project.targets.contains(where: { $0.name == "help" }) else { return project }
            let output = runHelp(in: URL(fileURLWithPath: project.directoryPath))
            let descriptions = parseHelpOutput(output)
            var enriched = project
            enriched.targets = project.targets.map { target in
                guard target.targetDescription == "No description available",
                      let description = descriptions[target.name] else { return target }
                var copy = target
                copy.targetDescription = description
                return copy
            }
            return enriched
        }
    }

    static func parseTargets(from contents: String) -> [MakeTarget] {
        let lines = contents.components(separatedBy: .newlines)
        var comments: [String] = []
        var descriptions: [String: String] = [:]
        var order: [String] = []

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let comment = trimmed.drop(while: { $0 == "#" || $0 == " " || $0 == "\t" })
                if !comment.isEmpty { comments.append(String(comment)) }
                continue
            }
            if trimmed.isEmpty {
                comments.removeAll()
                continue
            }
            if rawLine.hasPrefix("\t") || trimmed.hasPrefix(".") || trimmed.hasPrefix("define ") {
                comments.removeAll()
                continue
            }
            guard let colon = rawLine.firstIndex(of: ":") else {
                comments.removeAll()
                continue
            }
            let lhs = rawLine[..<colon].trimmingCharacters(in: .whitespaces)
            let afterColon = rawLine.index(after: colon)
            if afterColon < rawLine.endIndex, rawLine[afterColon] == "=" {
                comments.removeAll()
                continue
            }
            guard !lhs.isEmpty,
                  !lhs.contains("="), !lhs.contains("%"), !lhs.contains("$"), !lhs.contains("/"),
                  lhs.range(of: #"^[A-Za-z0-9][A-Za-z0-9_.-]*(?:\s+[A-Za-z0-9][A-Za-z0-9_.-]*)*$"#,
                            options: .regularExpression) != nil else {
                comments.removeAll()
                continue
            }

            let remainder = String(rawLine[rawLine.index(after: colon)...])
            let inlineDescription: String? = {
                guard let range = remainder.range(of: "##") else { return nil }
                let value = remainder[range.upperBound...].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }()
            let description = inlineDescription ?? (comments.isEmpty ? nil : comments.joined(separator: " "))

            for name in lhs.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init) {
                if descriptions[name] == nil { order.append(name) }
                if let description, descriptions[name] == nil || descriptions[name] == "No description available" {
                    descriptions[name] = description
                } else if descriptions[name] == nil {
                    descriptions[name] = "No description available"
                }
            }
            comments.removeAll()
        }

        return order.map { MakeTarget(name: $0, targetDescription: descriptions[$0] ?? "No description available") }
    }

    static func parseHelpOutput(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        let ansi = try? NSRegularExpression(pattern: #"\x1B\[[0-?]*[ -/]*[@-~]"#)
        let range = NSRange(output.startIndex..., in: output)
        let clean = ansi?.stringByReplacingMatches(in: output, range: range, withTemplate: "") ?? output

        for line in clean.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let match = trimmed.range(of: #"^([A-Za-z0-9_.-]+)(?:\s{2,}|\s*:\s+|\s+-\s+)(.+)$"#,
                                         options: .regularExpression) {
                let matched = String(trimmed[match])
                if let split = matched.range(of: #"(?:\s{2,}|\s*:\s+|\s+-\s+)"#,
                                             options: .regularExpression) {
                    let name = matched[..<split.lowerBound].trimmingCharacters(in: .whitespaces)
                    let description = matched[split.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty, !description.isEmpty { result[name] = description }
                }
            }
        }
        return result
    }

    private static func runHelp(in directory: URL) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        process.arguments = ["-s", "help"]
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ""
        }
        let deadline = Date().addingTimeInterval(4)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning { process.terminate() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func priority(of name: String) -> Int {
        makefileNames.firstIndex(of: name) ?? makefileNames.count
    }
}
