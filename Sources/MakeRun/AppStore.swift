import AppKit
import Darwin
import Foundation
import Observation
import UserNotifications

extension Notification.Name {
    static let makeRunOpenRun = Notification.Name("MakeRunOpenRun")
}

@MainActor
@Observable
final class AppStore {
    var roots: [SearchRoot] = []
    var projects: [MakeProject] = []
    var runs: [RunRecord] = []
    var selectedProjectID: UUID?
    var selectedTargetID: UUID?
    var selectedRunID: UUID?
    var searchText = ""
    var isIndexing = false
    var indexingStatus: String?
    var lastError: String?
    private var fontScaleStorage: Double
    var fontScale: Double {
        get { fontScaleStorage }
        set {
            let clamped = min(max(newValue, 0.8), 1.4)
            guard clamped != fontScaleStorage else { return }
            fontScaleStorage = clamped
            preferences.set(clamped, forKey: "fontScale")
        }
    }

    private let manager = FileManager.default
    private let appSupportURL: URL
    private let snapshotURL: URL
    private let runsURL: URL
    @ObservationIgnored private let preferences: UserDefaults

    init(preferences: UserDefaults = .standard, monitorRuns: Bool = true) {
        self.preferences = preferences
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Make Run", isDirectory: true)
        appSupportURL = support
        snapshotURL = support.appendingPathComponent("index.json")
        runsURL = support.appendingPathComponent("Runs", isDirectory: true)
        let savedScale = preferences.double(forKey: "fontScale")
        fontScaleStorage = savedScale == 0 ? 1 : min(max(savedScale, 0.8), 1.4)

        try? manager.createDirectory(at: runsURL, withIntermediateDirectories: true)
        load()
        normalizeRoots()
        save()
        selectedProjectID = projects.first?.id
        updateDockBadge()

        if monitorRuns {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.pollRunningJobs() }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .makeRunOpenRun,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let idString = notification.userInfo?["runID"] as? String,
                  let id = UUID(uuidString: idString) else { return }
            Task { @MainActor in self?.openRun(id, bringToFront: true) }
        }
    }

    var unreadCount: Int { runs.lazy.filter { !$0.isRead && $0.state != .running }.count }

    var favoriteProjects: [MakeProject] {
        projects.filter(\.isFavorite).sorted(by: projectNameOrder)
    }

    var otherProjects: [MakeProject] {
        projects.filter { !$0.isFavorite }.sorted(by: projectNameOrder)
    }

    var recentProjects: [MakeProject] {
        let dates = Dictionary(grouping: runs, by: \.projectID).mapValues { records in
            records.map(\.startedAt).max() ?? .distantPast
        }
        return projects.sorted {
            let lhs = dates[$0.id] ?? .distantPast
            let rhs = dates[$1.id] ?? .distantPast
            if lhs == rhs { return projectNameOrder($0, $1) }
            return lhs > rhs
        }
    }

    var selectedProject: MakeProject? {
        projects.first { $0.id == selectedProjectID }
    }

    var selectedTarget: MakeTarget? {
        selectedProject?.targets.first { $0.id == selectedTargetID }
    }

    var selectedRun: RunRecord? {
        runs.first { $0.id == selectedRunID }
    }

    func chooseSearchFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Folder to Search"
        panel.prompt = "Add Folder"
        panel.message = "Make Run will recursively index Makefiles in this folder."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK else { return }
        addSearchFolders(panel.urls)
    }

    func addSearchFolders(_ urls: [URL]) {
        for url in urls {
            let path = url.standardizedFileURL.path
            if !roots.contains(where: { $0.path == path }) {
                roots.append(SearchRoot(path: path))
            }
        }
        normalizeRoots()
        save()
        Task { await refreshIndex() }
    }

    func removeRoot(_ root: SearchRoot) {
        roots.removeAll { $0.id == root.id }
        save()
        Task { await refreshIndex() }
    }

    func refreshIndex() async {
        guard !isIndexing else { return }
        isIndexing = true
        indexingStatus = "Searching folders recursively…"
        lastError = nil
        let paths = roots.map(\.path)
        let discovered = await Task.detached(priority: .userInitiated) {
            MakefileParser.discoverProjects(in: paths, includeHelpDescriptions: false)
        }.value

        mergeDiscoveredProjects(discovered)
        indexingStatus = discovered.isEmpty
            ? "No Makefiles found"
            : "Found \(discovered.count) projects · Loading help descriptions…"
        save()

        let enriched = await Task.detached(priority: .utility) {
            MakefileParser.enrichHelpDescriptions(in: discovered)
        }.value
        mergeDiscoveredProjects(enriched)
        isIndexing = false
        indexingStatus = nil
        save()
    }

    private func mergeDiscoveredProjects(_ discovered: [DiscoveredProject]) {
        let oldByPath = Dictionary(uniqueKeysWithValues: projects.map { ($0.directoryPath, $0) })
        projects = discovered.map { item in
            guard let old = oldByPath[item.directoryPath] else {
                return MakeProject(
                    name: item.name,
                    directoryPath: item.directoryPath,
                    makefilePath: item.makefilePath,
                    targets: item.targets
                )
            }
            let oldTargets = Dictionary(uniqueKeysWithValues: old.targets.map { ($0.name, $0) })
            let mergedTargets = item.targets.map { target in
                guard let saved = oldTargets[target.name] else { return target }
                var merged = target
                merged.id = saved.id
                merged.isFavorite = saved.isFavorite
                merged.lastRunAt = saved.lastRunAt
                return merged
            }
            return MakeProject(
                id: old.id,
                name: item.name,
                directoryPath: item.directoryPath,
                makefilePath: item.makefilePath,
                createdAt: old.createdAt,
                lastIndexedAt: .now,
                isFavorite: old.isFavorite,
                targets: mergedTargets
            )
        }
        if selectedProjectID == nil || !projects.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = projects.first?.id
            selectedTargetID = nil
            selectedRunID = nil
        }
    }

    func toggleFavorite(projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].isFavorite.toggle()
        save()
    }

    func toggleFavorite(targetID: UUID, in projectID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }),
              let targetIndex = projects[projectIndex].targets.firstIndex(where: { $0.id == targetID }) else { return }
        projects[projectIndex].targets[targetIndex].isFavorite.toggle()
        save()
    }

    func quickTargets(for project: MakeProject) -> [MakeTarget] {
        var result: [MakeTarget] = []
        if let lastTargetID = runs.filter({ $0.projectID == project.id }).max(by: { $0.startedAt < $1.startedAt })?.targetID,
           let target = project.targets.first(where: { $0.id == lastTargetID }) {
            result.append(target)
        }
        for target in project.targets.filter(\.isFavorite).sorted(by: targetNameOrder) where !result.contains(where: { $0.id == target.id }) {
            result.append(target)
            if result.count == 3 { break }
        }
        return Array(result.prefix(3))
    }

    func runs(for projectID: UUID) -> [RunRecord] {
        runs.filter { $0.projectID == projectID }.sorted { $0.startedAt > $1.startedAt }
    }

    func runs(for projectID: UUID, targetID: UUID) -> [RunRecord] {
        runs.filter { $0.projectID == projectID && $0.targetID == targetID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func unreadCount(for projectID: UUID) -> Int {
        runs.lazy.filter { $0.projectID == projectID && !$0.isRead && $0.state != .running }.count
    }

    func markProjectRead(_ projectID: UUID) {
        for index in runs.indices where runs[index].projectID == projectID {
            runs[index].isRead = true
        }
        save()
        updateDockBadge()
    }

    func markAllRead() {
        for index in runs.indices { runs[index].isRead = true }
        save()
        updateDockBadge()
    }

    func selectProject(_ id: UUID?) {
        selectedProjectID = id
        selectedTargetID = nil
        selectedRunID = nil
    }

    func selectTarget(_ targetID: UUID) {
        selectedTargetID = targetID
        selectedRunID = nil
    }

    func openRun(_ runID: UUID, bringToFront: Bool = false) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        selectedProjectID = runs[index].projectID
        selectedTargetID = runs[index].targetID
        selectedRunID = runID
        runs[index].isRead = true
        save()
        updateDockBadge()
        if bringToFront {
            showMainWindow()
        }
    }

    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: {
            $0.level == .normal && $0.canBecomeMain && !($0 is NSPanel)
        }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let menuItems = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        if let newWindowItem = menuItems.first(where: {
            $0.action == Selector(("newWindow:")) || $0.title == "New Window"
        }), let action = newWindowItem.action {
            NSApp.sendAction(action, to: newWindowItem.target, from: newWindowItem)
        }
    }

    func run(target: MakeTarget, in project: MakeProject) {
        do {
            let id = UUID()
            let runDirectory = runsURL.appendingPathComponent(id.uuidString, isDirectory: true)
            try manager.createDirectory(at: runDirectory, withIntermediateDirectories: true)
            let logURL = runDirectory.appendingPathComponent("output.log")
            let statusURL = runDirectory.appendingPathComponent("exit-code")
            let scriptURL = runDirectory.appendingPathComponent("Run \(target.name).command")
            let header = "Make Run — \(project.name) / \(target.name)\nDirectory: \(project.directoryPath)\nStarted: \(Date().formatted())\n\n"
            let script = TerminalScriptBuilder.build(
                projectDirectory: project.directoryPath,
                targetName: target.name,
                logPath: logURL.path,
                statusPath: statusURL.path,
                header: header
            )
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let record = RunRecord(
                id: id,
                projectID: project.id,
                targetID: target.id,
                projectName: project.name,
                targetName: target.name,
                startedAt: .now,
                completedAt: nil,
                state: .running,
                exitCode: nil,
                logPath: logURL.path,
                statusPath: statusURL.path,
                isRead: true
            )
            runs.insert(record, at: 0)
            if let projectIndex = projects.firstIndex(where: { $0.id == project.id }),
               let targetIndex = projects[projectIndex].targets.firstIndex(where: { $0.id == target.id }) {
                projects[projectIndex].targets[targetIndex].lastRunAt = record.startedAt
            }
            selectedProjectID = project.id
            selectedTargetID = target.id
            selectedRunID = id
            save()

            let opener = Process()
            opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            opener.arguments = ["-a", "Terminal", scriptURL.path]
            try opener.run()
        } catch {
            lastError = "Couldn’t start \(target.name): \(error.localizedDescription)"
        }
    }

    func logText(for run: RunRecord?) -> String {
        guard let run else { return "" }
        return (try? String(contentsOfFile: run.logPath, encoding: .utf8)) ?? "Waiting for output…"
    }

    func revealProject(_ project: MakeProject) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.makefilePath)])
    }

    func openProjectFolder(_ project: MakeProject) {
        NSWorkspace.shared.open(URL(fileURLWithPath: project.directoryPath, isDirectory: true))
    }

    func resetFontScale() { fontScale = 1 }
    func increaseFontScale() { fontScale += 0.1 }
    func decreaseFontScale() { fontScale -= 0.1 }

    private func pollRunningJobs() {
        var completed: [RunRecord] = []
        for index in runs.indices where runs[index].state == .running {
            if let code = readExitCode(at: runs[index].statusPath) {
                completeRun(at: index, code: code, completedAt: .now)
                completed.append(runs[index])
                continue
            }

            let pidPath = TerminalScriptBuilder.launcherPIDPath(forStatusPath: runs[index].statusPath)
            if let pid = readPID(at: pidPath) {
                if !processExists(pid) {
                    appendInterruptedFooter(to: runs[index].logPath)
                    completeRun(at: index, code: 125, completedAt: .now)
                    completed.append(runs[index])
                }
                continue
            }

            if let inferred = inferLegacyCompletion(for: runs[index]) {
                completeRun(at: index, code: inferred.code, completedAt: inferred.date)
                completed.append(runs[index])
            }
        }
        guard !completed.isEmpty else { return }
        save()
        updateDockBadge()
        for record in completed { notifyCompletion(record) }
    }

    private func completeRun(at index: Int, code: Int32, completedAt: Date) {
        runs[index].exitCode = code
        runs[index].completedAt = completedAt
        runs[index].state = code == 0 ? .succeeded : .failed
        runs[index].isRead = isRunVisible(runs[index].id)
    }

    private func readExitCode(at path: String) -> Int32? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        return Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func readPID(at path: String) -> pid_t? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8),
              let value = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        return value
    }

    private func processExists(_ pid: pid_t) -> Bool {
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private func appendInterruptedFooter(to path: String) {
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\nMake Run launcher ended before reporting an exit code.\n".utf8))
        } catch {}
    }

    private func inferLegacyCompletion(for run: RunRecord) -> (code: Int32, date: Date)? {
        guard let attributes = try? manager.attributesOfItem(atPath: run.logPath),
              let modifiedAt = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modifiedAt) > 5,
              let log = try? String(contentsOfFile: run.logPath, encoding: .utf8) else { return nil }

        if let range = log.range(of: #"Make Run finished with exit code ([0-9]+)\."#,
                                 options: [.regularExpression, .backwards]) {
            let line = String(log[range])
            let digits = line.filter(\.isNumber)
            if let code = Int32(digits) { return (code, modifiedAt) }
        }
        if log.range(of: #"(?m)^make(?:\[[0-9]+\])?: \*\*\* .+ Error [0-9]+\s*$"#,
                     options: .regularExpression) != nil {
            return (2, modifiedAt)
        }
        return nil
    }

    private func notifyCompletion(_ run: RunRecord) {
        let content = UNMutableNotificationContent()
        content.title = "\(run.projectName): \(run.targetName)"
        content.body = run.state == .succeeded ? "Completed successfully." : "Failed with exit code \(run.exitCode ?? -1)."
        content.sound = run.state == .succeeded ? .default : UNNotificationSound(named: UNNotificationSoundName("Basso"))
        content.badge = NSNumber(value: unreadCount)
        content.userInfo = ["runID": run.id.uuidString]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: run.id.uuidString, content: content, trigger: nil))
    }

    private func load() {
        guard let data = try? Data(contentsOf: snapshotURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(AppSnapshot.self, from: data) else { return }
        roots = snapshot.roots
        projects = snapshot.projects
        runs = snapshot.runs
    }

    private func save() {
        do {
            try manager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(AppSnapshot(roots: roots, projects: projects, runs: runs))
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            lastError = "Couldn’t save the local index: \(error.localizedDescription)"
        }
    }

    private func updateDockBadge() {
        NSApplication.shared.dockTile.badgeLabel = unreadCount == 0 ? nil : String(unreadCount)
    }

    private func normalizeRoots() {
        let sorted = roots.sorted {
            if $0.path.count == $1.path.count { return $0.addedAt < $1.addedAt }
            return $0.path.count < $1.path.count
        }
        var normalized: [SearchRoot] = []
        for root in sorted {
            let path = URL(fileURLWithPath: root.path).standardizedFileURL.path
            let isCovered = normalized.contains { existing in
                path == existing.path || path.hasPrefix(existing.path + "/")
            }
            if !isCovered {
                var copy = root
                copy.path = path
                normalized.append(copy)
            }
        }
        roots = normalized
    }

    private func isRunVisible(_ id: UUID) -> Bool {
        selectedRunID == id
            && NSApplication.shared.isActive
            && NSApp.windows.contains { $0.title == "Make Run" && $0.isVisible && $0.isKeyWindow }
    }

    private func projectNameOrder(_ lhs: MakeProject, _ rhs: MakeProject) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func targetNameOrder(_ lhs: MakeTarget, _ rhs: MakeTarget) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

}
