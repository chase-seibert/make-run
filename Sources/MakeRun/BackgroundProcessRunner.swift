import Foundation

final class BackgroundProcessLaunch {
    let process: Process
    let logHandle: FileHandle

    init(process: Process, logHandle: FileHandle) {
        self.process = process
        self.logHandle = logHandle
    }
}

enum BackgroundProcessRunner {
    static func prepare(
        projectDirectory: String,
        targetName: String,
        logPath: String,
        statusPath: String,
        header: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> BackgroundProcessLaunch {
        try Data(header.utf8).write(to: URL(fileURLWithPath: logPath), options: .atomic)
        let logHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
        try logHandle.seekToEnd()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", shellCommand, "Make Run", targetName, statusPath]
        process.currentDirectoryURL = URL(fileURLWithPath: projectDirectory, isDirectory: true)
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle
        return BackgroundProcessLaunch(process: process, logHandle: logHandle)
    }

    static func processPIDPath(forStatusPath statusPath: String) -> String {
        statusPath + "-process-pid"
    }

    private static let shellCommand = #"""
    status_written=0
    finalize() {
        code="$1"
        if [ "$status_written" -eq 1 ]; then return; fi
        status_written=1
        /usr/bin/printf '%s' "$code" > "$2.tmp"
        /bin/mv "$2.tmp" "$2"
        /usr/bin/printf '\nMake Run finished with exit code %s.\n' "$code"
    }
    interrupted() {
        code="$1"
        trap - EXIT HUP INT TERM
        finalize "$code" "$2"
        exit "$code"
    }
    trap 'interrupted 129 "$2"' HUP
    trap 'interrupted 130 "$2"' INT
    trap 'interrupted 143 "$2"' TERM
    trap 'code=$?; finalize "$code" "$2"' EXIT
    /usr/bin/make "$1"
    exit $?
    """#
}
