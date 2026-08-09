import Foundation

struct GitChange: Identifiable, Equatable {
    let status: String
    let path: String

    var id: String { path }

    var displayStatus: String {
        switch status {
        case "??": "New"
        case let value where value.contains("M"): "Modified"
        case let value where value.contains("D"): "Deleted"
        case let value where value.contains("A"): "Added"
        default: status.trimmingCharacters(in: .whitespaces)
        }
    }

    var hasStagedChange: Bool {
        guard let first = status.first else { return false }
        return first != " " && first != "?"
    }

    var isConflicted: Bool {
        let conflicts: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]
        return conflicts.contains(status) || status.contains("U")
    }

    var isRenameOrCopy: Bool {
        status.contains("R") || status.contains("C")
    }
}

struct PublishCheck: Identifiable, Equatable {
    enum State: Equatable {
        case passed
        case blocked
        case information
    }

    let id = UUID()
    let title: String
    let detail: String
    let state: State

    static func == (lhs: PublishCheck, rhs: PublishCheck) -> Bool {
        lhs.title == rhs.title && lhs.detail == rhs.detail && lhs.state == rhs.state
    }
}

struct PublishPreflight {
    let repositoryRoot: URL
    let branch: String
    let upstream: String
    let ahead: Int
    let behind: Int
    let remoteURL: String
    let headSHA: String
    let changes: [GitChange]
    let checks: [PublishCheck]
    let fingerprint: String

    var blockers: [PublishCheck] { checks.filter { $0.state == .blocked } }
    var canPublish: Bool { blockers.isEmpty && !changes.isEmpty }

    var relationshipDescription: String {
        if ahead > 0 && behind > 0 { return "Diverged: \(ahead) ahead, \(behind) behind" }
        if ahead > 0 { return "Ahead by \(ahead) commit\(ahead == 1 ? "" : "s")" }
        if behind > 0 { return "Behind by \(behind) commit\(behind == 1 ? "" : "s")" }
        return "Up to date"
    }
}

enum PublishStage: String {
    case preflight = "Preflight"
    case rebuild = "Rebuild and validation"
    case staging = "Staging"
    case commit = "Commit"
    case push = "Push"
}

struct PublishResult {
    let stagedFiles: [String]
    let commitSHA: String?
    let commitOutput: String?
    let pushOutput: String?
    let failureStage: PublishStage?
    let failureMessage: String?

    var succeeded: Bool { commitSHA != nil && pushOutput != nil && failureStage == nil }
}

struct PublishOperationError: LocalizedError {
    let stage: PublishStage
    let message: String
    let result: PublishResult?

    var errorDescription: String? { "\(stage.rawValue) failed. \(message)" }
}
