import Foundation

enum MissionControlFeature: String, CaseIterable, Identifiable {
    case lessonVisibility
    case publishToMain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lessonVisibility: "Lesson Visibility"
        case .publishToMain: "Publish to Main"
        }
    }

    var subtitle: String {
        switch self {
        case .lessonVisibility: "Choose what students can see"
        case .publishToMain: "Review, commit, and push safely"
        }
    }

    var systemImage: String {
        switch self {
        case .lessonVisibility: "eye"
        case .publishToMain: "arrow.up.circle"
        }
    }
}
