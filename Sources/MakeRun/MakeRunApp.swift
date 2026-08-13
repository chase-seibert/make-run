import AppKit
import SwiftUI

@main
struct MakeRunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup("Make Run", id: "main") {
            MainWindow(store: store)
                .frame(minWidth: 960, minHeight: 620)
                .environment(\.fontScale, store.fontScale)
        }
        .defaultSize(width: 1240, height: 760)
        .commands {
            AppCommands(store: store)
        }

        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            Label {
                Text(store.unreadCount == 0 ? "Make Run" : "Make Run, \(store.unreadCount) unread")
            } icon: {
                Image(systemName: store.unreadCount == 0 ? "play.square.stack" : "play.square.stack.fill")
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: store)
                .frame(width: 560, height: 420)
                .environment(\.fontScale, store.fontScale)
        }
    }
}

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

extension EnvironmentValues {
    var fontScale: Double {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    let store: AppStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Search Folder…") { store.chooseSearchFolder() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Refresh Index") { Task { await store.refreshIndex() } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.roots.isEmpty || store.isIndexing)
        }

        CommandMenu("Run") {
            Button("Run Selected Target") {
                if let project = store.selectedProject, let target = store.selectedTarget {
                    store.run(target: target, in: project)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(store.selectedProject == nil || store.selectedTarget == nil)

            Divider()
            Button("Mark All Runs as Read") { store.markAllRead() }
                .disabled(store.unreadCount == 0)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            Button("Make Text Bigger") { store.increaseFontScale() }
                .keyboardShortcut("+", modifiers: .command)
            Button("Make Text Smaller") { store.decreaseFontScale() }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { store.resetFontScale() }
                .keyboardShortcut("0", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Make Run Help") {
                let alert = NSAlert()
                alert.messageText = "Make Run Help"
                alert.informativeText = "Add a search folder with Command-O, select a project and target, then press Command-Return to run it. Use the sidebar or menu bar item for quick runs. Live and completed output remains available under Recent Runs."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
