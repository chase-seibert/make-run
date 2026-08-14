import AppKit
import SwiftUI

struct MainWindow: View {
    @Bindable var store: AppStore

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 260, ideal: 315, max: 400)
        } content: {
            TargetBrowser(store: store)
                .navigationSplitViewColumnWidth(min: 260, ideal: 330, max: 460)
        } detail: {
            DetailPane(store: store)
        }
        .appFont(.body)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isIndexing {
                    ProgressView()
                        .controlSize(.small)
                        .help("Refreshing index")
                }
                Button {
                    Task { await store.refreshIndex() }
                } label: {
                    Label("Refresh Index", systemImage: "arrow.clockwise")
                }
                .disabled(store.roots.isEmpty || store.isIndexing)

                Button(action: store.chooseSearchFolder) {
                    Label("Add Search Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert("Make Run", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

private struct ProjectSidebar: View {
    @Bindable var store: AppStore
    @FocusState private var projectSearchIsFocused: Bool

    private var visibleFavoriteProjects: [MakeProject] {
        store.favoriteProjects.filter { store.matchingProjects.contains($0) }
    }

    private var visibleOtherProjects: [MakeProject] {
        store.otherProjects.filter { store.matchingProjects.contains($0) }
    }

    var body: some View {
        Group {
            if store.projects.isEmpty, store.isIndexing {
                ContentUnavailableView {
                    Label("Searching for Makefiles", systemImage: "folder.badge.questionmark")
                } description: {
                    Text(store.indexingStatus ?? "Crawling your folders recursively…")
                } actions: {
                    ProgressView().controlSize(.small)
                }
            } else if store.projects.isEmpty {
                ContentUnavailableView {
                    Label("No Makefile Projects", systemImage: "hammer")
                } description: {
                    Text(store.roots.isEmpty
                         ? "Choose a folder to recursively find Makefiles."
                         : "No Makefiles were found in your search folders.")
                } actions: {
                    Button("Add Search Folder…", action: store.chooseSearchFolder)
                }
            } else {
                ScrollViewReader { proxy in
                    List(selection: Binding(
                        get: { store.selectedProjectID },
                        set: { store.selectProject($0) }
                    )) {
                        if !visibleFavoriteProjects.isEmpty {
                            Section {
                                ForEach(visibleFavoriteProjects) { project in
                                    ProjectRow(store: store, project: project)
                                        .tag(project.id)
                                }
                            } header: {
                                ScaledSectionHeader("Favorites")
                            }
                        }
                        Section {
                            ForEach(visibleOtherProjects) { project in
                                ProjectRow(store: store, project: project)
                                    .tag(project.id)
                            }
                        } header: {
                            ScaledSectionHeader("Projects")
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: store.projectSearchDismissRequest) { _, _ in
                        projectSearchIsFocused = false
                        guard let selectedProjectID = store.selectedProjectID else { return }
                        DispatchQueue.main.async {
                            proxy.scrollTo(selectedProjectID, anchor: .center)
                        }
                    }
                    .safeAreaInset(edge: .top) {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Find projects", text: $store.projectSearchText)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($projectSearchIsFocused)
                                    .onChange(of: store.projectSearchText) { _, _ in
                                        store.selectFirstProjectMatchingSearch()
                                    }
                                if !store.projectSearchText.isEmpty {
                                    Button {
                                        store.projectSearchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.secondary)
                                    .help("Clear project search")
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.bar)

                            if store.isIndexing, let status = store.indexingStatus {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text(status).appFont(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.bar)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .onChange(of: store.projectSearchFocusRequest) { _, _ in
            projectSearchIsFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if store.unreadCount > 0 {
                    Button("Mark All Read") { store.markAllRead() }
                        .help("Mark all completed runs as read")
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let store: AppStore
    let project: MakeProject
    @Environment(\.fontScale) private var fontScale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if !project.isFavorite {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
                Text(project.name)
                    .appFont(.body, weight: .medium)
                    .lineLimit(1)
                Spacer(minLength: 4)
                let unread = store.unreadCount(for: project.id)
                if unread > 0 {
                    Text("\(unread)")
                        .appFont(.caption2, weight: .bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                        .accessibilityLabel("\(unread) unread runs")
                }
            }
            let quick = store.quickTargets(for: project)
            if !quick.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(quick.enumerated()), id: \.element.id) { index, target in
                        Button {
                            store.run(target: target, in: project)
                        } label: {
                            HStack(spacing: 4) {
                                Label(target.name, systemImage: "play.fill")
                                    .appFont(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if store.selectedProjectID == project.id {
                                    Text("⌘\(index + 1)")
                                        .appFont(.caption2, weight: .semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(AppTypography.quickActionControlSize(for: fontScale))
                        .help("Run make \(target.name)")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(project.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(projectID: project.id)
            }
            Button("Reveal Makefile in Finder") { store.revealProject(project) }
            if store.unreadCount(for: project.id) > 0 {
                Divider()
                Button("Mark All as Read") { store.markProjectRead(project.id) }
            }
        }
    }
}

private struct TargetBrowser: View {
    @Bindable var store: AppStore

    private var filteredTargets: [MakeTarget] {
        guard let project = store.selectedProject else { return [] }
        let targets = project.targets
        guard !store.searchText.isEmpty else { return targets }
        return targets.filter {
            $0.name.localizedCaseInsensitiveContains(store.searchText)
                || $0.targetDescription.localizedCaseInsensitiveContains(store.searchText)
        }
    }

    var body: some View {
        Group {
            if let project = store.selectedProject {
                List {
                    let favorites = filteredTargets.filter(\.isFavorite).sorted(by: targetOrder)
                    if !favorites.isEmpty {
                        Section {
                            ForEach(favorites) { target in TargetRow(store: store, project: project, target: target) }
                        } header: {
                            ScaledSectionHeader("Favorite Targets")
                        }
                    }

                    let recent = Array(store.runs(for: project.id).prefix(10))
                    if !recent.isEmpty, store.searchText.isEmpty {
                        Section {
                            ForEach(recent) { run in RunRow(store: store, run: run) }
                        } header: {
                            ScaledSectionHeader("Recent Runs")
                        }
                    }

                    Section {
                        ForEach(filteredTargets.sorted(by: targetOrder)) { target in
                            TargetRow(store: store, project: project, target: target)
                        }
                    } header: {
                        ScaledSectionHeader("All Targets")
                    }
                }
                .navigationTitle(project.name)
                .searchable(text: $store.searchText, placement: .toolbar, prompt: "Find targets")
                .safeAreaInset(edge: .top) {
                    ProjectLocationBar(store: store, project: project)
                }
            } else {
                ContentUnavailableView("Select a Project", systemImage: "sidebar.left")
            }
        }
    }

    private func targetOrder(_ lhs: MakeTarget, _ rhs: MakeTarget) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

private struct ProjectLocationBar: View {
    let store: AppStore
    let project: MakeProject

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(project.name)
                .appFont(.headline, weight: .semibold)
                .lineLimit(1)
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(project.directoryPath)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(project.directoryPath)
                Spacer(minLength: 8)
                Button {
                    store.openProjectFolder(project)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Open project folder in Finder")
                .accessibilityLabel("Open project folder in Finder")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct TargetRow: View {
    let store: AppStore
    let project: MakeProject
    let target: MakeTarget

    var body: some View {
        Button {
            store.selectTarget(target.id)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: target.isFavorite ? "star.fill" : "hammer")
                    .foregroundStyle(target.isFavorite ? .yellow : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).appFont(.body, weight: .medium)
                    Text(target.targetDescription)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    store.run(target: target, in: project)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Run make \(target.name)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .contextMenu {
            Button("Run \(target.name)") { store.run(target: target, in: project) }
            Button(target.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(targetID: target.id, in: project.id)
            }
        }
    }
}

private struct RunRow: View {
    let store: AppStore
    let run: RunRecord

    var body: some View {
        Button { store.openRun(run.id) } label: {
            HStack(spacing: 8) {
                RunStatusIcon(state: run.state)
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.targetName).appFont(.body).lineLimit(1)
                    RunDurationLabel(run: run)
                }
                Spacer()
                if !run.isRead && run.state != .running {
                    Circle().fill(.blue).frame(width: 7, height: 7)
                        .accessibilityLabel("Unread")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

private struct RunDurationLabel: View {
    let run: RunRecord

    var body: some View {
        if run.state == .running {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Running · \(RunDurationFormatter.string(for: run.elapsed(at: context.date)))")
            }
            .foregroundStyle(.blue)
            .accessibilityLabel("Running for \(RunDurationFormatter.string(for: run.elapsed()))")
            .appFont(.caption)
        } else {
            Text("\(run.state.label) · \(RunDurationFormatter.string(for: run.elapsed()))")
                .foregroundStyle(.secondary)
                .appFont(.caption)
        }
    }
}

private struct ScaledSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .appFont(.subheadline, weight: .semibold)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

private struct RunStatusIcon: View {
    let state: RunState

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(color)
            .accessibilityLabel(state.label)
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
