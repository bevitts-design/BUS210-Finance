import Foundation

enum MissionControlFeature: String, CaseIterable, Identifiable {
    case lessonVisibility
    case publishToMain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lessonVisibility: "Lesson Access"
        case .publishToMain: "Publish to Main"
        }
    }

    var subtitle: String {
        switch self {
        case .lessonVisibility: "Choose which lessons students can open"
        case .publishToMain: "Review, commit, and push safely"
        }
    }

    var systemImage: String {
        switch self {
        case .lessonVisibility: "lock.open"
        case .publishToMain: "arrow.up.circle"
        }
    }
}
