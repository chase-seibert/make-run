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
                    .appFont(.caption)
                    .foregroundStyle(.secondary)

                GroupBox("Preview") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Favorites")
                            .appFont(.subheadline, weight: .semibold)
                            .foregroundStyle(.secondary)
                        Text("Example Project")
                            .appFont(.body, weight: .medium)
                        Label("phone-deploy", systemImage: "play.fill")
                            .appFont(.caption)
                        Text("Make target description")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
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
        .appFont(.body)
        .navigationTitle("Make Run Settings")
    }
}
