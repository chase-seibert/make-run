import Foundation

struct SearchRoot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var path: String
    var addedAt: Date

    init(id: UUID = UUID(), path: String, addedAt: Date = .now) {
        self.id = id
        self.path = path
        self.addedAt = addedAt
    }
}

struct MakeTarget: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var targetDescription: String
    var isFavorite: Bool
    var lastRunAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        targetDescription: String = "No description available",
        isFavorite: Bool = false,
        lastRunAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.targetDescription = targetDescription
        self.isFavorite = isFavorite
        self.lastRunAt = lastRunAt
    }
}

struct MakeProject: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var directoryPath: String
    var makefilePath: String
    var createdAt: Date
    var lastIndexedAt: Date
    var isFavorite: Bool
    var targets: [MakeTarget]

    init(
        id: UUID = UUID(),
        name: String,
        directoryPath: String,
        makefilePath: String,
        createdAt: Date = .now,
        lastIndexedAt: Date = .now,
        isFavorite: Bool = false,
        targets: [MakeTarget] = []
    ) {
        self.id = id
        self.name = name
        self.directoryPath = directoryPath
        self.makefilePath = makefilePath
        self.createdAt = createdAt
        self.lastIndexedAt = lastIndexedAt
        self.isFavorite = isFavorite
        self.targets = targets
    }
}

enum RunState: String, Codable, Hashable, Sendable {
    case running
    case succeeded
    case failed

    var label: String {
        switch self {
        case .running: "Running"
        case .succeeded: "Succeeded"
        case .failed: "Failed"
        }
    }
}

struct RunRecord: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var projectID: UUID
    var targetID: UUID
    var projectName: String
    var targetName: String
    var startedAt: Date
    var completedAt: Date?
    var state: RunState
    var exitCode: Int32?
    var logPath: String
    var statusPath: String
    var isRead: Bool

    func elapsed(at date: Date = .now) -> TimeInterval {
        max(0, (completedAt ?? date).timeIntervalSince(startedAt))
    }
}

enum RunDurationFormatter {
    static func string(for interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 { return "\(hours) hr \(minutes) min" }
        if minutes > 0 { return "\(minutes) min \(seconds) sec" }
        return "\(seconds) sec"
    }
}

struct AppSnapshot: Codable, Sendable {
    var roots: [SearchRoot] = []
    var projects: [MakeProject] = []
    var runs: [RunRecord] = []
}

struct DiscoveredProject: Sendable {
    var name: String
    var directoryPath: String
    var makefilePath: String
    var targets: [MakeTarget]
}
