import Foundation

struct GitCommandResult {
    let output: String
    let exitCode: Int32
}

enum GitPublishServiceError: LocalizedError {
    case invalidRepository(String)
    case commandFailed(title: String, exitCode: Int32, output: String)
    case unsafeToPublish([String])
    case worktreeChanged
    case invalidCommitMessage

    var errorDescription: String? {
        switch self {
        case .invalidRepository(let detail): detail
        case .commandFailed(let title, let exitCode, let output):
            "\(title) failed with exit code \(exitCode).\n\(output)"
        case .unsafeToPublish(let blockers):
            "Publishing is blocked:\n• \(blockers.joined(separator: "\n• "))"
        case .worktreeChanged:
            "Files changed after preflight. Run preflight again so the exact publishing scope can be reviewed."
        case .invalidCommitMessage:
            "Enter a concise commit message before publishing."
        }
    }
}

struct PublishSafetyPolicy {
    static let expectedRemoteURLs: Set<String> = [
        "https://github.com/bevitts-design/BUS210-Finance.git",
        "https://github.com/bevitts-design/BUS210-Finance",
        "git@github.com:bevitts-design/BUS210-Finance.git",
        "git@github.com:bevitts-design/BUS210-Finance",
        "ssh://git@github.com/bevitts-design/BUS210-Finance.git",
        "ssh://git@github.com/bevitts-design/BUS210-Finance",
    ]

    static let allowedPaths: Set<String> = [
        ".codex/environments/environment.toml",
        ".gitignore",
        "BUS210Welcome_Canvas.html",
        "deliverables/fall-2026/BUS210_01_Welcome_Canvas.html",
        "deliverables/fall-2026/BUS210_02_Welcome_Canvas.html",
        "index.html",
        "course-map.json",
        "MissionControl/Assets/AppIcon.svg",
        "MissionControl/Package.swift",
        "MissionControl/README.md",
        "MissionControl/Sources/BUS210MissionControl/App/BUS210MissionControlApp.swift",
        "MissionControl/Sources/BUS210MissionControl/Models/CourseMapModels.swift",
        "MissionControl/Sources/BUS210MissionControl/Models/MissionControlFeature.swift",
        "MissionControl/Sources/BUS210MissionControl/Models/PublishingModels.swift",
        "MissionControl/Sources/BUS210MissionControl/Services/CourseMapService.swift",
        "MissionControl/Sources/BUS210MissionControl/Services/GitPublishService.swift",
        "MissionControl/Sources/BUS210MissionControl/Services/JSONSourceEditor.swift",
        "MissionControl/Sources/BUS210MissionControl/Services/RepositoryLocator.swift",
        "MissionControl/Sources/BUS210MissionControl/Services/WorkflowService.swift",
        "MissionControl/Sources/BUS210MissionControl/Stores/MissionControlStore.swift",
        "MissionControl/Sources/BUS210MissionControl/Stores/PublishStore.swift",
        "MissionControl/Sources/BUS210MissionControl/Views/ChangePreviewView.swift",
        "MissionControl/Sources/BUS210MissionControl/Views/ContentView.swift",
        "MissionControl/Sources/BUS210MissionControl/Views/LessonVisibilityView.swift",
        "MissionControl/Sources/BUS210MissionControl/Views/PublishToMainView.swift",
        "MissionControl/Tests/CoreChecks/main.swift",
        "script/build_and_run.sh",
        "script/build_app_icon.sh",
        "script/test_mission_control_core.sh",
        "scripts/build-index.mjs",
        "scripts/build-welcome-pages.mjs",
        "scripts/lib/course-map.mjs",
        "scripts/validate-course-map.mjs",
        "tests/course-map.test.mjs",
    ]

    static let requiredSourcePaths = [
        "course-map.json",
        "scripts/build-index.mjs",
        "scripts/build-welcome-pages.mjs",
        "scripts/validate-course-map.mjs",
        "tests/course-map.test.mjs",
    ]

    static func blockers(
        branch: String,
        upstream: String,
        ahead: Int,
        behind: Int,
        remoteURL: String,
        changes: [GitChange],
        missingRequiredPaths: [String]
    ) -> [String] {
        var result: [String] = []
        if branch != "main" { result.append("The current branch is \(branch.isEmpty ? "unknown" : branch), not main.") }
        if upstream != "origin/main" { result.append("main must track origin/main; current upstream is \(upstream.isEmpty ? "unavailable" : upstream).") }
        if ahead > 0 && behind > 0 {
            result.append("The branch has diverged from origin/main (\(ahead) ahead, \(behind) behind).")
        } else {
            if ahead > 0 { result.append("There are \(ahead) existing unpushed commit\(ahead == 1 ? "" : "s").") }
            if behind > 0 { result.append("The checkout is \(behind) commit\(behind == 1 ? "" : "s") behind origin/main.") }
        }
        if !expectedRemoteURLs.contains(remoteURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) {
            result.append("origin does not point to the expected bevitts-design/BUS210-Finance repository.")
        }
        if !missingRequiredPaths.isEmpty {
            result.append("Required source-of-truth files are missing: \(missingRequiredPaths.joined(separator: ", ")).")
        }
        if changes.isEmpty { result.append("There are no reviewed BUS210 changes to publish.") }
        let conflicts = changes.filter(\.isConflicted).map(\.path)
        if !conflicts.isEmpty { result.append("Resolve Git conflicts first: \(conflicts.joined(separator: ", ")).") }
        let staged = changes.filter(\.hasStagedChange).map(\.path)
        if !staged.isEmpty { result.append("Pre-existing staged changes must be reviewed and unstaged first: \(staged.joined(separator: ", ")).") }
        let renamed = changes.filter(\.isRenameOrCopy).map(\.path)
        if !renamed.isEmpty { result.append("Renamed or copied paths require manual review: \(renamed.joined(separator: ", ")).") }
        let unrelated = changes.map(\.path).filter { !allowedPaths.contains($0) }
        if !unrelated.isEmpty { result.append("Unrelated or unreviewed paths are present: \(unrelated.joined(separator: ", ")).") }
        return result
    }

    static func stageArguments(for changes: [GitChange]) -> [String] {
        ["add", "--"] + changes.map(\.path).sorted()
    }

    static func isValidCommitMessage(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains("\n") && trimmed.count <= 120
    }
}

struct GitPublishService {
    private let fileManager = FileManager.default

    func preflight(repositoryRoot: URL) async throws -> PublishPreflight {
        try await Task.detached(priority: .userInitiated) {
            try preflightSynchronously(repositoryRoot: repositoryRoot)
        }.value
    }

    func publish(
        repositoryRoot: URL,
        reviewedPreflight: PublishPreflight,
        commitMessage: String
    ) async throws -> PublishResult {
        try await Task.detached(priority: .userInitiated) {
            try publishSynchronously(
                repositoryRoot: repositoryRoot,
                reviewedPreflight: reviewedPreflight,
                commitMessage: commitMessage
            )
        }.value
    }

    private func preflightSynchronously(repositoryRoot: URL) throws -> PublishPreflight {
        try validateRepositoryRoot(repositoryRoot)

        _ = try runGit(
            ["fetch", "--prune", "origin", "main"],
            at: repositoryRoot,
            title: "Fetch origin/main"
        )

        let branch = try runGit(["symbolic-ref", "--quiet", "--short", "HEAD"], at: repositoryRoot, title: "Read current branch").output
        let upstreamResult = runGitAllowingFailure(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], at: repositoryRoot)
        let upstream = upstreamResult.exitCode == 0 ? upstreamResult.output : ""
        let remoteURLResult = runGitAllowingFailure(["remote", "get-url", "origin"], at: repositoryRoot)
        let remoteURL = remoteURLResult.exitCode == 0 ? remoteURLResult.output : ""
        let headSHA = try runGit(["rev-parse", "--short", "HEAD"], at: repositoryRoot, title: "Read current commit").output
        let countsResult = runGitAllowingFailure(["rev-list", "--left-right", "--count", "HEAD...origin/main"], at: repositoryRoot)
        let counts = parseAheadBehind(countsResult.exitCode == 0 ? countsResult.output : "")
        let statusData = try runGitData(["status", "--porcelain=v1", "-z", "--untracked-files=all"], at: repositoryRoot, title: "Read worktree status")
        let changes = parsePorcelainStatus(statusData)
        let missing = PublishSafetyPolicy.requiredSourcePaths.filter {
            !fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent($0).path)
        }

        var blockerMessages = PublishSafetyPolicy.blockers(
            branch: branch,
            upstream: upstream,
            ahead: counts.ahead,
            behind: counts.behind,
            remoteURL: remoteURL,
            changes: changes,
            missingRequiredPaths: missing
        )
        var checks: [PublishCheck] = []

        if blockerMessages.isEmpty {
            checks.append(.init(title: "Git safety", detail: "main matches origin/main and every changed path is in the reviewed BUS210 scope.", state: .passed))
        } else {
            checks.append(contentsOf: blockerMessages.map { .init(title: "Git safety", detail: $0, state: .blocked) })
        }

        let validationCommands: [(String, URL, [String])] = [
            ("Course map and generated homepage", try locateNode(), ["scripts/validate-course-map.mjs"]),
            ("Section 01 and 02 welcome pages", try locateNode(), ["scripts/build-welcome-pages.mjs", "--check"]),
            ("Course-map tests", try locateNode(), ["--test", "tests/course-map.test.mjs"]),
            ("Mission Control safety checks", repositoryRoot.appendingPathComponent("script/test_mission_control_core.sh"), []),
            ("Whitespace and conflict markers", URL(fileURLWithPath: "/usr/bin/git"), ["diff", "--check"]),
        ]

        for (title, executable, arguments) in validationCommands {
            let result = runProcessAllowingFailure(executable: executable, arguments: arguments, at: repositoryRoot)
            if result.exitCode == 0 {
                checks.append(.init(title: title, detail: result.output.isEmpty ? "Passed." : result.output, state: .passed))
            } else {
                let detail = result.output.isEmpty ? "Exited with code \(result.exitCode)." : result.output
                checks.append(.init(title: title, detail: detail, state: .blocked))
                blockerMessages.append("\(title) failed.")
            }
        }

        let canCheckAuthentication = branch == "main" && upstream == "origin/main" && counts.ahead == 0 && counts.behind == 0
        if canCheckAuthentication {
            let authentication = runGitAllowingFailure(["push", "--dry-run", "--porcelain", "origin", "main:main"], at: repositoryRoot)
            if authentication.exitCode == 0 {
                checks.append(.init(title: "GitHub authentication", detail: "A non-interactive dry-run push succeeded; no commit was created or sent.", state: .passed))
            } else {
                checks.append(.init(title: "GitHub authentication", detail: authentication.output.isEmpty ? "GitHub authentication was unavailable." : authentication.output, state: .blocked))
            }
        } else {
            checks.append(.init(title: "GitHub authentication", detail: "Not checked until main is synchronized with origin/main.", state: .blocked))
        }

        let fingerprint = try worktreeFingerprint(repositoryRoot: repositoryRoot, changes: changes)
        return PublishPreflight(
            repositoryRoot: repositoryRoot,
            branch: branch,
            upstream: upstream,
            ahead: counts.ahead,
            behind: counts.behind,
            remoteURL: remoteURL,
            headSHA: headSHA,
            changes: changes,
            checks: checks,
            fingerprint: fingerprint
        )
    }

    private func publishSynchronously(
        repositoryRoot: URL,
        reviewedPreflight: PublishPreflight,
        commitMessage: String
    ) throws -> PublishResult {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PublishSafetyPolicy.isValidCommitMessage(message) else {
            throw GitPublishServiceError.invalidCommitMessage
        }
        let currentFingerprint = try worktreeFingerprint(repositoryRoot: repositoryRoot, changes: reviewedPreflight.changes)
        guard currentFingerprint == reviewedPreflight.fingerprint else { throw GitPublishServiceError.worktreeChanged }

        do {
            let node = try locateNode()
            _ = try runProcess(executable: node, arguments: ["scripts/build-index.mjs"], at: repositoryRoot, title: "Rebuild student homepage")
            _ = try runProcess(executable: node, arguments: ["scripts/build-welcome-pages.mjs"], at: repositoryRoot, title: "Rebuild welcome pages")
            _ = try runProcess(executable: node, arguments: ["scripts/validate-course-map.mjs"], at: repositoryRoot, title: "Validate course map")
            _ = try runProcess(executable: node, arguments: ["scripts/build-welcome-pages.mjs", "--check"], at: repositoryRoot, title: "Validate welcome pages")
            _ = try runProcess(executable: node, arguments: ["--test", "tests/course-map.test.mjs"], at: repositoryRoot, title: "Run course-map tests")
            _ = try runProcess(executable: repositoryRoot.appendingPathComponent("script/test_mission_control_core.sh"), arguments: [], at: repositoryRoot, title: "Run Mission Control safety checks")
            _ = try runGit(["diff", "--check"], at: repositoryRoot, title: "Check Git diff")
        } catch {
            throw PublishOperationError(stage: .rebuild, message: error.localizedDescription, result: nil)
        }

        let finalPreflight: PublishPreflight
        do {
            finalPreflight = try preflightSynchronously(repositoryRoot: repositoryRoot)
        } catch {
            throw PublishOperationError(stage: .preflight, message: error.localizedDescription, result: nil)
        }
        guard finalPreflight.canPublish else {
            throw GitPublishServiceError.unsafeToPublish(finalPreflight.blockers.map(\.detail))
        }
        guard finalPreflight.fingerprint == reviewedPreflight.fingerprint else {
            throw GitPublishServiceError.worktreeChanged
        }

        let paths = finalPreflight.changes.map(\.path).sorted()
        do {
            _ = try runGit(PublishSafetyPolicy.stageArguments(for: finalPreflight.changes), at: repositoryRoot, title: "Stage reviewed BUS210 paths")
            let stagedData = try runGitData(["diff", "--cached", "--name-only", "-z"], at: repositoryRoot, title: "Verify staged paths")
            let stagedPaths = String(decoding: stagedData, as: UTF8.self).split(separator: "\0").map(String.init).sorted()
            guard stagedPaths == paths else {
                throw GitPublishServiceError.unsafeToPublish(["The staged paths did not exactly match the reviewed preflight scope."])
            }
        } catch {
            throw PublishOperationError(
                stage: .staging,
                message: error.localizedDescription,
                result: PublishResult(stagedFiles: paths, commitSHA: nil, commitOutput: nil, pushOutput: nil, failureStage: .staging, failureMessage: error.localizedDescription)
            )
        }

        let commitOutput: String
        do {
            commitOutput = try runGit(["commit", "-m", message, "--"], at: repositoryRoot, title: "Create commit").output
        } catch {
            throw PublishOperationError(
                stage: .commit,
                message: error.localizedDescription,
                result: PublishResult(stagedFiles: paths, commitSHA: nil, commitOutput: nil, pushOutput: nil, failureStage: .commit, failureMessage: error.localizedDescription)
            )
        }

        let commitSHA = (try? runGit(["rev-parse", "--short", "HEAD"], at: repositoryRoot, title: "Read commit").output) ?? "created"
        do {
            let pushOutput = try runGit(["push", "--porcelain", "origin", "main:main"], at: repositoryRoot, title: "Push main").output
            return PublishResult(stagedFiles: paths, commitSHA: commitSHA, commitOutput: commitOutput, pushOutput: pushOutput, failureStage: nil, failureMessage: nil)
        } catch {
            let partial = PublishResult(
                stagedFiles: paths,
                commitSHA: commitSHA,
                commitOutput: commitOutput,
                pushOutput: nil,
                failureStage: .push,
                failureMessage: error.localizedDescription
            )
            throw PublishOperationError(stage: .push, message: "Commit \(commitSHA) was created locally, but the push failed. The recovery view preserves this status. \(error.localizedDescription)", result: partial)
        }
    }

    private func validateRepositoryRoot(_ root: URL) throws {
        let normalized = root.standardizedFileURL
        var gitIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: normalized.appendingPathComponent(".git").path, isDirectory: &gitIsDirectory), gitIsDirectory.boolValue else {
            if fileManager.fileExists(atPath: normalized.appendingPathComponent(".git").path) {
                throw GitPublishServiceError.invalidRepository("Publishing is blocked from linked or temporary Git worktrees. Choose the primary BUS210 checkout instead.")
            }
            throw GitPublishServiceError.invalidRepository("The selected folder is not a Git checkout.")
        }
        guard normalized.lastPathComponent == "BUS210-Finance" else {
            throw GitPublishServiceError.invalidRepository("Publishing is limited to the BUS210-Finance repository.")
        }
    }

    private func runGit(_ arguments: [String], at root: URL, title: String) throws -> GitCommandResult {
        let result = runGitAllowingFailure(arguments, at: root)
        guard result.exitCode == 0 else {
            throw GitPublishServiceError.commandFailed(title: title, exitCode: result.exitCode, output: result.output)
        }
        return result
    }

    private func runGitAllowingFailure(_ arguments: [String], at root: URL) -> GitCommandResult {
        runProcessAllowingFailure(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: arguments, at: root)
    }

    private func runGitData(_ arguments: [String], at root: URL, title: String) throws -> Data {
        let result = runProcessData(executable: URL(fileURLWithPath: "/usr/bin/git"), arguments: arguments, at: root)
        guard result.exitCode == 0 else {
            throw GitPublishServiceError.commandFailed(title: title, exitCode: result.exitCode, output: String(decoding: result.data, as: UTF8.self))
        }
        return result.data
    }

    private func runProcess(executable: URL, arguments: [String], at root: URL, title: String) throws -> GitCommandResult {
        let result = runProcessAllowingFailure(executable: executable, arguments: arguments, at: root)
        guard result.exitCode == 0 else {
            throw GitPublishServiceError.commandFailed(title: title, exitCode: result.exitCode, output: result.output)
        }
        return result
    }

    private func runProcessAllowingFailure(executable: URL, arguments: [String], at root: URL) -> GitCommandResult {
        let result = runProcessData(executable: executable, arguments: arguments, at: root)
        return GitCommandResult(
            output: String(decoding: result.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: result.exitCode
        )
    }

    private func runProcessData(executable: URL, arguments: [String], at root: URL) -> (data: Data, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GCM_INTERACTIVE"] = "Never"
        environment["LC_ALL"] = "C"
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (data, process.terminationStatus)
        } catch {
            return (Data(error.localizedDescription.utf8), -1)
        }
    }

    private func worktreeFingerprint(repositoryRoot: URL, changes: [GitChange]) throws -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for change in changes.sorted(by: { $0.path < $1.path }) {
            let header = Data("\(change.status)\0\(change.path)\0".utf8)
            updateFNV1a(&hash, with: header)
            let file = repositoryRoot.appendingPathComponent(change.path)
            if fileManager.fileExists(atPath: file.path), let data = try? Data(contentsOf: file) {
                updateFNV1a(&hash, with: data)
            } else {
                updateFNV1a(&hash, with: Data("<missing>".utf8))
            }
        }
        return String(format: "%016llx", hash)
    }

    private func updateFNV1a(_ hash: inout UInt64, with data: Data) {
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
    }
}

func parsePorcelainStatus(_ data: Data) -> [GitChange] {
    let fields = data.split(separator: 0, omittingEmptySubsequences: true).map { String(decoding: $0, as: UTF8.self) }
    var changes: [GitChange] = []
    var index = 0
    while index < fields.count {
        let field = fields[index]
        guard field.count >= 4 else { index += 1; continue }
        let status = String(field.prefix(2))
        let path = String(field.dropFirst(3))
        changes.append(GitChange(status: status, path: path))
        if status.contains("R") || status.contains("C") { index += 1 }
        index += 1
    }
    return changes.sorted { $0.path < $1.path }
}

func parseAheadBehind(_ output: String) -> (ahead: Int, behind: Int) {
    let values = output.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
    guard values.count == 2 else { return (0, 0) }
    return (values[0], values[1])
}

private func locateNode(fileManager: FileManager = .default) throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    var candidates: [String] = []
    if let configured = environment["BUS210_NODE_PATH"], !configured.isEmpty { candidates.append(configured) }
    if let path = environment["PATH"] {
        candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/node" })
    }
    candidates.append(contentsOf: ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"])
    let home = fileManager.homeDirectoryForCurrentUser.path
    candidates.append("\(home)/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node")
    for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
        return URL(fileURLWithPath: candidate)
    }
    throw GitPublishServiceError.invalidRepository("Node.js is required for publishing validation but could not be found. Set BUS210_NODE_PATH or install Node.js.")
}
