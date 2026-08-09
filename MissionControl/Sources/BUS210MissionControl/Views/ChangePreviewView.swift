import SwiftUI

struct ChangePreviewView: View {
    @ObservedObject var store: MissionControlStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Review Before Save")
                    .font(.title3.weight(.semibold))
                Text("Only each lesson’s access field will change. Every card remains listed on the homepage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.changes.isEmpty {
                        ContentUnavailableView {
                            Label("No Pending Changes", systemImage: "checkmark.circle")
                        } description: {
                            Text("Use a switch to prepare an access change.")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        ForEach(store.changes) { change in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: change.systemImage)
                                    .foregroundStyle(change.willBeVisible ? .green : .orange)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(change.action) \(change.lesson.code)")
                                        .font(.callout.weight(.semibold))
                                    Text(change.lesson.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Divider()
                        Label("After save: \(store.availableAfterSaveCount) lessons available to open", systemImage: "lock.open")
                            .font(.callout.weight(.medium))
                    }

                    if !store.workflowResults.isEmpty {
                        Divider()
                        Text("Completed Workflow")
                            .font(.headline)
                        ForEach(Array(store.workflowResults.enumerated()), id: \.offset) { _, result in
                            VStack(alignment: .leading, spacing: 3) {
                                Label(result.title, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                if !result.output.isEmpty {
                                    Text(result.output)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            VStack(spacing: 10) {
                Button {
                    store.saveAndRebuild()
                } label: {
                    HStack {
                        if store.isWorking { ProgressView().controlSize(.small) }
                        Text(store.isWorking ? "Saving and rebuilding…" : "Save and Rebuild")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.isDirty || store.isWorking)

                Button("Discard Changes") { store.discardChanges() }
                    .disabled(!store.isDirty || store.isWorking)
            }
            .padding(18)
        }
        .background(.regularMaterial)
    }
}

enum StatusBannerKind {
    case error
    case success
}

struct StatusBanner: View {
    let kind: StatusBannerKind
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(kind == .error ? .orange : .green)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(12)
        .background((kind == .error ? Color.orange : Color.green).opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}
