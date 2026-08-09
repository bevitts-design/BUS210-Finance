import Foundation

enum WorkflowServiceError: LocalizedError {
    case nodeUnavailable
    case stepFailed(title: String, exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .nodeUnavailable:
            "Node.js is required for the BUS210 generation workflow but could not be found. Set BUS210_NODE_PATH or install Node.js."
        case .stepFailed(let title, let exitCode, let output):
            "\(title) failed with exit code \(exitCode).\n\(output)"
        }
    }
}

struct WorkflowService {
    func run(repositoryRoot: URL) async throws -> [WorkflowStepResult] {
        try await Task.detached(priority: .userInitiated) {
            let nodeURL = try locateNode()
            let steps = [
                ("Rebuild student homepage", "scripts/build-index.mjs"),
                ("Validate course map", "scripts/validate-course-map.mjs"),
            ]
            return try steps.map { title, script in
                let output = try runProcess(
                    executableURL: nodeURL,
                    arguments: [script],
                    currentDirectoryURL: repositoryRoot,
                    title: title
                )
                return WorkflowStepResult(title: title, output: output)
            }
        }.value
    }
}

private func locateNode(fileManager: FileManager = .default) throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    var candidates: [String] = []
    if let configured = environment["BUS210_NODE_PATH"], !configured.isEmpty { candidates.append(configured) }
    if let path = environment["PATH"] {
        candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/node" })
    }
    candidates.append(contentsOf: ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"])
    if let home = fileManager.homeDirectoryForCurrentUser.path.removingPercentEncoding {
        candidates.append("\(home)/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node")
    }
    for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
        return URL(fileURLWithPath: candidate)
    }
    throw WorkflowServiceError.nodeUnavailable
}

private func runProcess(
    executableURL: URL,
    arguments: [String],
    currentDirectoryURL: URL,
    title: String
) throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0 else {
        throw WorkflowServiceError.stepFailed(title: title, exitCode: process.terminationStatus, output: output)
    }
    return output
}
