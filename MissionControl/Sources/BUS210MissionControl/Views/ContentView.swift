import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: MissionControlStore
    @ObservedObject var publishStore: PublishStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedFeature) {
                Section("Course Controls") {
                    featureRow(.lessonVisibility)
                }
                Section("Publishing") {
                    featureRow(.publishToMain)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 285)
            .safeAreaInset(edge: .bottom) {
                RepositoryStatusView(store: store)
            }
        } detail: {
            switch store.selectedFeature ?? .lessonVisibility {
            case .lessonVisibility:
                LessonVisibilityView(store: store)
            case .publishToMain:
                PublishToMainView(store: publishStore, missionControlStore: store)
            }
        }
    }

    private func featureRow(_ feature: MissionControlFeature) -> some View {
        HStack(spacing: 10) {
            Image(systemName: feature.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tag(feature)
    }
}

private struct RepositoryStatusView: View {
    @ObservedObject var store: MissionControlStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(store.snapshot == nil ? "Course source unavailable" : "Course source connected",
                  systemImage: store.snapshot == nil ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(store.snapshot == nil ? .orange : .green)
            if let path = store.repositoryPath {
                Text(path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(path)
            } else {
                Text("Choose the folder that contains course-map.json and the BUS210 build scripts.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(store.snapshot == nil ? "Choose Repository…" : "Change Repository…") {
                chooseRepository(for: store)
            }
            .font(.caption)
            .disabled(store.isWorking || store.isDirty)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

@MainActor
func chooseRepository(for store: MissionControlStore) {
    let panel = NSOpenPanel()
    panel.title = "Choose the BUS210-Finance Repository"
    panel.message = "Select the folder containing course-map.json and the scripts folder. Mission Control validates it before remembering the location."
    panel.prompt = "Choose Repository"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/GitHub", isDirectory: true)

    if panel.runModal() == .OK, let selectedURL = panel.url {
        store.load(repositoryRoot: selectedURL)
    }
}
