import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore

    var body: some View {
        TabView {
            Form {
                HStack {
                    Text("Text size")
                    Slider(value: $store.fontScale, in: 0.8...1.4, step: 0.1)
                    Text("\(Int(store.fontScale * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                    Button("Reset") { store.resetFontScale() }
                }
                Text("Use Command-plus, Command-minus, and Command-zero from any app window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("Appearance", systemImage: "textformat.size") }

            VStack(alignment: .leading, spacing: 12) {
                List {
                    ForEach(store.roots) { root in
                        HStack {
                            Image(systemName: "folder")
                            Text(root.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button {
                                store.removeRoot(root)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove search folder")
                        }
                    }
                }
                HStack {
                    Button("Add Folder…", action: store.chooseSearchFolder)
                    Spacer()
                    Button("Refresh Now") { Task { await store.refreshIndex() } }
                        .disabled(store.roots.isEmpty || store.isIndexing)
                }
            }
            .padding(16)
            .tabItem { Label("Search Folders", systemImage: "folder.badge.gearshape") }
        }
        .navigationTitle("Make Run Settings")
    }
}
