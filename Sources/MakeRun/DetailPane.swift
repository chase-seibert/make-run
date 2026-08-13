import SwiftUI

struct DetailPane: View {
    @Bindable var store: AppStore
    @Environment(\.fontScale) private var fontScale

    var body: some View {
        Group {
            if let run = store.selectedRun {
                RunDetail(store: store, run: run, consoleFontSize: 13 * fontScale)
            } else if let project = store.selectedProject, let target = store.selectedTarget {
                TargetDetail(store: store, project: project, target: target)
            } else if store.selectedProject != nil {
                ContentUnavailableView("Select a Target or Run", systemImage: "hammer")
            } else {
                ContentUnavailableView("Choose a Project", systemImage: "folder")
            }
        }
    }
}

private struct TargetDetail: View {
    let store: AppStore
    let project: MakeProject
    let target: MakeTarget

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(target.name).appFont(.largeTitle, weight: .bold)
                        Text("make \(target.name)")
                            .appFont(.body, design: .monospaced)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        store.toggleFavorite(targetID: target.id, in: project.id)
                    } label: {
                        Image(systemName: target.isFavorite ? "star.fill" : "star")
                    }
                    .help(target.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    Button {
                        store.run(target: target, in: project)
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                }

                GroupBox("Description") {
                    Text(target.targetDescription)
                        .appFont(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }

                LabeledContent("Project", value: project.name)
                LabeledContent("Directory", value: project.directoryPath)
                    .textSelection(.enabled)
                LabeledContent("First found") {
                    Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Last run") {
                    Text(target.lastRunAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                }

                let targetRuns = store.runs(for: project.id, targetID: target.id)
                if !targetRuns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Runs").appFont(.headline, weight: .semibold)
                        ForEach(targetRuns.prefix(12)) { run in
                            Button { store.openRun(run.id) } label: {
                                HStack {
                                    RunStatusPill(state: run.state)
                                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    Spacer()
                                    if let code = run.exitCode { Text("Exit \(code)").foregroundStyle(.secondary) }
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                                .padding(8)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .navigationTitle(target.name)
    }
}

private struct RunDetail: View {
    let store: AppStore
    let run: RunRecord
    let consoleFontSize: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RunStatusPill(state: run.state)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(run.projectName) / \(run.targetName)").appFont(.headline, weight: .semibold)
                    HStack(spacing: 5) {
                        Text(run.startedAt.formatted(date: .abbreviated, time: .standard))
                        Text("·")
                        if run.state == .running {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(RunDurationFormatter.string(for: run.elapsed(at: context.date)))
                            }
                        } else {
                            Text(RunDurationFormatter.string(for: run.elapsed()))
                        }
                    }
                    .appFont(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let exitCode = run.exitCode {
                    Text("Exit code \(exitCode)").foregroundStyle(.secondary)
                }
                if let project = store.projects.first(where: { $0.id == run.projectID }),
                   let target = project.targets.first(where: { $0.id == run.targetID }) {
                    Button {
                        store.run(target: target, in: project)
                    } label: {
                        Label("Run Again", systemImage: "arrow.clockwise")
                    }
                }
            }
            .padding(16)
            .background(.bar)

            Divider()

            if run.state == .running {
                TimelineView(.periodic(from: .now, by: 0.75)) { _ in
                    WrappedConsoleTextView(text: store.logText(for: run), fontSize: consoleFontSize)
                        .id(run.id)
                }
            } else {
                WrappedConsoleTextView(text: store.logText(for: run), fontSize: consoleFontSize)
                    .id(run.id)
            }
        }
        .navigationTitle(run.targetName)
    }
}

private struct RunStatusPill: View {
    let state: RunState

    var body: some View {
        Label(state.label, systemImage: icon)
            .appFont(.caption, weight: .bold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var icon: String {
        switch state {
        case .running: "progress.indicator"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
    private var color: Color {
        switch state {
        case .running: .blue
        case .succeeded: .green
        case .failed: .red
        }
    }
}
