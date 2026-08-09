import SwiftUI

struct LessonVisibilityView: View {
    @ObservedObject var store: MissionControlStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let message = store.errorMessage {
                StatusBanner(kind: .error, message: message)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
            if let message = store.successMessage {
                StatusBanner(kind: .success, message: message)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
            if let map = store.courseMap {
                HSplitView {
                    lessonList(map: map)
                        .frame(minWidth: 520)
                    ChangePreviewView(store: store)
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
                }
            } else {
                unavailableState
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.load()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(store.isWorking || store.isDirty)
                .help(store.isDirty ? "Discard or save the pending changes before reloading." : "Reload course-map.json")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lesson Access")
                        .font(.largeTitle.weight(.semibold))
                    Text("Every lesson card stays listed. Choose which lessons students can open; locked cards show a coming-soon preview without a link.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let map = store.courseMap {
                    Text("\(store.availableAfterSaveCount) of \(map.lessons.count) available")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            TextField("Search lessons", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
        }
        .padding(20)
    }

    private func lessonList(map: CourseMap) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(map.modules) { module in
                    let lessons = store.lessons(in: module)
                    if !lessons.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.badge.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tint)
                                Text(module.title)
                                    .font(.title3.weight(.semibold))
                            }
                            ForEach(lessons) { lesson in
                                LessonVisibilityRow(
                                    lesson: lesson,
                                    isVisible: Binding(
                                        get: { store.isVisible(lesson.id) },
                                        set: { store.setVisible($0, for: lesson.id) }
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var unavailableState: some View {
        ContentUnavailableView {
            Label("Course Map Unavailable", systemImage: "doc.badge.ellipsis")
        } description: {
            Text("Mission Control will not make changes until it can safely read the BUS210 source files.")
        } actions: {
            HStack {
                Button("Choose Repository…") { chooseRepository(for: store) }
                Button("Try Again") { store.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LessonVisibilityRow: View {
    let lesson: CourseMapLesson
    @Binding var isVisible: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(lesson.code)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(lesson.status == "comingSoon" ? "COMING SOON" : "LIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(lesson.status == "comingSoon" ? .orange : .green)
                }
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.topic)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle(isOn: $isVisible) {
                Text(isVisible ? "Available" : "Locked")
                    .frame(width: 68, alignment: .trailing)
            }
            .toggleStyle(.switch)
            .accessibilityLabel("\(lesson.title) student access")
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }
}
