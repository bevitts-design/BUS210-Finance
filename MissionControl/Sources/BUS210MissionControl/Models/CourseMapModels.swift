import Foundation

struct CourseMapModule: Identifiable, Equatable {
    let id: String
    let badge: String
    let title: String
    let displayOrder: Double
}

struct CourseMapLesson: Identifiable, Equatable {
    let id: String
    let moduleID: String
    let code: String
    let title: String
    let topic: String
    let status: String
    let visible: Bool
    let displayOrder: Double
}

struct CourseMap: Equatable {
    let courseCode: String
    let courseTitle: String
    let modules: [CourseMapModule]
    let lessons: [CourseMapLesson]

    var visibleLessonCount: Int { lessons.filter(\.visible).count }
}

struct CourseMapSnapshot {
    let map: CourseMap
    let sourceData: Data
    let sourceURL: URL
    let repositoryRoot: URL
}

struct VisibilityChange: Identifiable, Equatable {
    let lesson: CourseMapLesson
    let wasVisible: Bool
    let willBeVisible: Bool

    var id: String { lesson.id }
    var action: String { willBeVisible ? "Show" : "Hide" }
    var systemImage: String { willBeVisible ? "eye" : "eye.slash" }
}

struct WorkflowStepResult: Equatable {
    let title: String
    let output: String
}

enum ValidationSeverity: String {
    case error
    case warning
}

struct ValidationIssue: Identifiable, Equatable {
    let severity: ValidationSeverity
    let message: String

    var id: String { "\(severity.rawValue):\(message)" }
}
