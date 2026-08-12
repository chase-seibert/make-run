import Foundation

enum TerminalScriptBuilder {
    static func build(
        projectDirectory: String,
        targetName: String,
        logPath: String,
        statusPath: String,
        header: String
    ) -> String {
        let pidPath = launcherPIDPath(forStatusPath: statusPath)
        let innerCommand = "cd \(shellQuote(projectDirectory)); set -o pipefail; /usr/bin/make \(shellQuote(targetName)) 2>&1 | /usr/bin/tee -a \(shellQuote(logPath)); exit ${PIPESTATUS[0]}"
        return """
        #!/bin/bash
        set +e
        status_written=0
        finalize() {
            code="$1"
            if [ "$status_written" -eq 1 ]; then return; fi
            status_written=1
            /usr/bin/printf '%s' "$code" > \(shellQuote(statusPath + ".tmp"))
            /bin/mv \(shellQuote(statusPath + ".tmp")) \(shellQuote(statusPath))
            /usr/bin/printf '\nMake Run finished with exit code %s.\n' "$code" | /usr/bin/tee -a \(shellQuote(logPath))
        }
        interrupted() {
            code="$1"
            trap - EXIT HUP INT TERM
            finalize "$code"
            exit "$code"
        }
        trap 'interrupted 129' HUP
        trap 'interrupted 130' INT
        trap 'interrupted 143' TERM
        trap 'code=$?; finalize "$code"' EXIT
        /usr/bin/printf '%s' "$$" > \(shellQuote(pidPath))
        /usr/bin/printf '%s' \(shellQuote(header)) > \(shellQuote(logPath))
        /bin/bash -lic \(shellQuote(innerCommand))
        code=$?
        exit "$code"
        """
    }

    static func launcherPIDPath(forStatusPath statusPath: String) -> String {
        statusPath + "-launcher-pid"
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
