import AppKit
import SwiftUI

struct MenuBarContent: View {
    let store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !store.favoriteProjects.isEmpty {
            Section("Favorite Projects") {
                ForEach(store.favoriteProjects) { project in
                    ProjectMenu(project: project, store: store)
                }
            }
        }

        let recent = Array(store.recentProjects.filter { project in
            !store.favoriteProjects.contains(where: { $0.id == project.id })
        }.prefix(5))
        if !recent.isEmpty {
            Section("Recent Projects") {
                ForEach(recent) { project in
                    ProjectMenu(project: project, store: store)
                }
            }
        }

        if store.projects.isEmpty {
            Text("No indexed projects")
            Button("Add Search Folder…") { store.chooseSearchFolder() }
        }

        Divider()
        Button("Open Make Run") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        if store.unreadCount > 0 {
            Button("Mark \(store.unreadCount) Runs as Read") { store.markAllRead() }
        }
        Button("Refresh Index") { Task { await store.refreshIndex() } }
            .disabled(store.roots.isEmpty || store.isIndexing)
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit Make Run") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct ProjectMenu: View {
    let project: MakeProject
    let store: AppStore

    var body: some View {
        Menu {
            let quick = store.quickTargets(for: project)
            if quick.isEmpty {
                Text("No recent or favorite targets")
            } else {
                ForEach(quick) { target in
                    Button {
                        store.run(target: target, in: project)
                    } label: {
                        Label(target.name, systemImage: "play.fill")
                    }
                }
            }
            Divider()
            Button("Show Project") {
                store.selectProject(project.id)
                store.showMainWindow()
            }
        } label: {
            let unread = store.unreadCount(for: project.id)
            Label(unread == 0 ? project.name : "\(project.name) (\(unread))",
                  systemImage: project.isFavorite ? "star.fill" : "folder")
        }
    }
}
