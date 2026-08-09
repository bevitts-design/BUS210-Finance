import Foundation

private enum CheckFailure: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure.failed(message) }
}

private func makeRepository(jsonData: Data) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("BUS210MissionControlChecks-\(UUID().uuidString)", isDirectory: true)
    try makeRepository(at: root, jsonData: jsonData)
    return root
}

private func makeRepository(at root: URL, jsonData: Data) throws {
    try FileManager.default.createDirectory(at: root.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    try jsonData.write(to: root.appendingPathComponent("course-map.json"))
    try Data().write(to: root.appendingPathComponent("scripts/build-index.mjs"))
    try Data().write(to: root.appendingPathComponent("scripts/validate-course-map.mjs"))
}

private func readGitStatus(at root: URL) throws -> Data {
    let process = Process()
    let output = Pipe()
    let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["status", "--porcelain=v1", "-z", "--untracked-files=all"]
    process.currentDirectoryURL = root
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CheckFailure.failed("Could not inspect the actual publishing scope: \(String(decoding: errorData, as: UTF8.self))")
    }
    return data
}

private let service = CourseMapService()
private let repositoryRoot = URL(
    fileURLWithPath: ProcessInfo.processInfo.environment["BUS210_REPO_ROOT"] ?? FileManager.default.currentDirectoryPath,
    isDirectory: true
)

do {
    let actualSnapshot = try service.load(repositoryRoot: repositoryRoot)
    try require(actualSnapshot.map.courseCode == "BUS210", "Actual course code was not BUS210.")
    try require(actualSnapshot.map.lessons.count == 10, "Actual course map did not contain 10 lessons.")
    try require(Set(actualSnapshot.map.lessons.map(\.id)).count == 10, "Actual course map contains duplicate lesson IDs.")

    let locatorHome = FileManager.default.temporaryDirectory
        .appendingPathComponent("BUS210MissionControlLocator-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: locatorHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: locatorHome) }
    let defaultsName = "BUS210MissionControlChecks.\(UUID().uuidString)"
    guard let locatorDefaults = UserDefaults(suiteName: defaultsName) else {
        throw CheckFailure.failed("Could not create isolated locator preferences.")
    }
    defer { locatorDefaults.removePersistentDomain(forName: defaultsName) }
    let previousDirectory = FileManager.default.currentDirectoryPath
    try require(FileManager.default.changeCurrentDirectoryPath(locatorHome.path), "Could not isolate the locator working directory.")
    defer { _ = FileManager.default.changeCurrentDirectoryPath(previousDirectory) }

    let canonicalRoot = locatorHome.appendingPathComponent("Documents/GitHub/BUS210-Finance", isDirectory: true)
    try makeRepository(at: canonicalRoot, jsonData: actualSnapshot.sourceData)
    let canonicalResult = RepositoryLocator.locate(
        userDefaults: locatorDefaults,
        homeDirectory: locatorHome,
        environment: [:]
    )
    try require(canonicalResult?.standardizedFileURL == canonicalRoot.standardizedFileURL, "Locator did not prefer the canonical GitHub checkout.")

    try FileManager.default.removeItem(at: canonicalRoot)
    let worktreeA = locatorHome.appendingPathComponent(".codex/worktrees/a/BUS210-Finance", isDirectory: true)
    try makeRepository(at: worktreeA, jsonData: actualSnapshot.sourceData)
    let uniqueWorktreeResult = RepositoryLocator.locate(
        userDefaults: locatorDefaults,
        homeDirectory: locatorHome,
        environment: [:]
    )
    try require(uniqueWorktreeResult?.standardizedFileURL == worktreeA.standardizedFileURL, "Locator did not accept the single complete worktree fallback.")

    let worktreeB = locatorHome.appendingPathComponent(".codex/worktrees/b/BUS210-Finance", isDirectory: true)
    try makeRepository(at: worktreeB, jsonData: actualSnapshot.sourceData)
    let ambiguousResult = RepositoryLocator.locate(
        userDefaults: locatorDefaults,
        homeDirectory: locatorHome,
        environment: [:]
    )
    try require(ambiguousResult == nil, "Locator guessed between multiple complete worktrees instead of requiring a user choice.")

    let incompleteSelection = locatorHome.appendingPathComponent("Incomplete-BUS210", isDirectory: true)
    try FileManager.default.createDirectory(at: incompleteSelection, withIntermediateDirectories: true)
    try actualSnapshot.sourceData.write(to: incompleteSelection.appendingPathComponent("course-map.json"))
    do {
        _ = try service.load(repositoryRoot: incompleteSelection)
        throw CheckFailure.failed("An explicitly selected folder without the BUS210 build scripts was accepted.")
    } catch CourseMapServiceError.repositoryNotFound {
        // Expected safety block.
    }

    let roundTripRoot = try makeRepository(jsonData: actualSnapshot.sourceData)
    defer { try? FileManager.default.removeItem(at: roundTripRoot) }
    let roundTripSnapshot = try service.load(repositoryRoot: roundTripRoot)
    _ = try service.writeVisibilityChanges(snapshot: roundTripSnapshot, visibilityByLessonID: ["m01": false])
    let changed = try service.load(repositoryRoot: roundTripRoot)
    try require(changed.map.lessons.first(where: { $0.id == "m01" })?.visible == false, "Real course-map copy did not persist the narrow visibility change.")
    try require(changed.map.lessons.filter(\.visible).count == actualSnapshot.map.lessons.filter(\.visible).count - 1, "The visibility write changed more than the selected lesson.")
    _ = try service.writeVisibilityChanges(snapshot: changed, visibilityByLessonID: ["m01": true])
    let restoredBytes = try Data(contentsOf: roundTripRoot.appendingPathComponent("course-map.json"))
    try require(restoredBytes == actualSnapshot.sourceData, "The narrow hide/show round-trip changed unrelated source bytes.")

    let unknownRoot = try makeRepository(jsonData: Data(#"""
    {
      "schemaVersion": 1,
      "course": { "code": "BUS210", "title": "Finance" },
      "modules": [{ "id": "tvm", "badge": "TVM", "title": "Time Value of Money", "displayOrder": 10 }],
      "lessons": [{
        "id": "m01", "moduleId": "tvm", "code": "BUS210 · M01", "title": "Introduction",
        "topic": "Finance foundations", "status": "live", "visible": true, "displayOrder": 10,
        "links": [{ "label": "Open lesson", "url": "https://example.com", "style": "primary" }],
        "futureLessonField": "preserve"
      }],
      "futureRootField": "preserve"
    }
    """#.utf8))
    defer { try? FileManager.default.removeItem(at: unknownRoot) }
    let unknownSnapshot = try service.load(repositoryRoot: unknownRoot)
    _ = try service.writeVisibilityChanges(snapshot: unknownSnapshot, visibilityByLessonID: ["m01": false])
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: unknownRoot.appendingPathComponent("course-map.json"))) as? [String: Any]
    try require(object?["futureRootField"] as? String == "preserve", "Unknown root field was not preserved.")
    let lessons = object?["lessons"] as? [[String: Any]]
    try require(lessons?.first?["futureLessonField"] as? String == "preserve", "Unknown lesson field was not preserved.")

    let staleSnapshot = try service.load(repositoryRoot: unknownRoot)
    try Data("{}\n".utf8).write(to: unknownRoot.appendingPathComponent("course-map.json"), options: .atomic)
    do {
        _ = try service.writeVisibilityChanges(snapshot: staleSnapshot, visibilityByLessonID: ["m01": true])
        throw CheckFailure.failed("A stale save was incorrectly accepted.")
    } catch CourseMapServiceError.externallyModified {
        // Expected safety block.
    }

    let malformedRoot = try makeRepository(jsonData: Data(#"""
    {"schemaVersion":1,"course":{"code":"BUS210","title":"Finance"},"modules":[],"lessons":[{"id":"bad","visible":"yes"}]}
    """#.utf8))
    defer { try? FileManager.default.removeItem(at: malformedRoot) }
    do {
        _ = try service.load(repositoryRoot: malformedRoot)
        throw CheckFailure.failed("Malformed visibility was incorrectly accepted.")
    } catch CourseMapServiceError.invalidSource {
        // Expected safety block.
    }

    let parsedChanges = parsePorcelainStatus(Data(" M course-map.json\0?? MissionControl/README.md\0".utf8))
    try require(parsedChanges.count == 2, "Publishing preflight did not parse tracked and untracked changes.")
    try require(parsedChanges.first(where: { $0.path == "course-map.json" })?.displayStatus == "Modified", "Publishing preflight did not preserve the course-map status.")
    try require(parsedChanges.first(where: { $0.path == "MissionControl/README.md" })?.displayStatus == "New", "Publishing preflight did not preserve the untracked Mission Control status.")

    let safeBlockers = PublishSafetyPolicy.blockers(
        branch: "main",
        upstream: "origin/main",
        ahead: 0,
        behind: 0,
        remoteURL: "git@github.com:bevitts-design/BUS210-Finance.git",
        changes: parsedChanges,
        missingRequiredPaths: []
    )
    try require(safeBlockers.isEmpty, "The reviewed BUS210 publishing scope was incorrectly blocked: \(safeBlockers.joined(separator: " | "))")

    let unrelatedBlockers = PublishSafetyPolicy.blockers(
        branch: "main",
        upstream: "origin/main",
        ahead: 0,
        behind: 0,
        remoteURL: "https://github.com/bevitts-design/BUS210-Finance.git",
        changes: [GitChange(status: "??", path: "private-answer-key.xlsx")],
        missingRequiredPaths: []
    )
    try require(unrelatedBlockers.contains(where: { $0.contains("Unrelated or unreviewed") }), "An unrelated untracked file was not blocked.")

    let hostileRemoteBlockers = PublishSafetyPolicy.blockers(
        branch: "main",
        upstream: "origin/main",
        ahead: 0,
        behind: 0,
        remoteURL: "https://github.com/bevitts-design/BUS210-Finance.git.example.invalid",
        changes: parsedChanges,
        missingRequiredPaths: []
    )
    try require(hostileRemoteBlockers.contains(where: { $0.contains("expected bevitts-design") }), "A lookalike GitHub remote was not blocked.")

    let unsafeGitBlockers = PublishSafetyPolicy.blockers(
        branch: "feature",
        upstream: "origin/main",
        ahead: 1,
        behind: 2,
        remoteURL: "https://github.com/bevitts-design/BUS210-Finance.git",
        changes: [GitChange(status: "UU", path: "course-map.json")],
        missingRequiredPaths: ["scripts/validate-course-map.mjs"]
    )
    try require(unsafeGitBlockers.contains(where: { $0.contains("not main") }), "A non-main branch was not blocked.")
    try require(unsafeGitBlockers.contains(where: { $0.contains("diverged") }), "A diverged branch was not blocked.")
    try require(unsafeGitBlockers.contains(where: { $0.contains("conflicts") }), "A conflicted file was not blocked.")
    try require(unsafeGitBlockers.contains(where: { $0.contains("staged") }), "A pre-staged conflicted file was not blocked.")
    try require(unsafeGitBlockers.contains(where: { $0.contains("source-of-truth") }), "A missing source-of-truth file was not blocked.")

    let stageArguments = PublishSafetyPolicy.stageArguments(for: parsedChanges)
    try require(Array(stageArguments.prefix(2)) == ["add", "--"], "Publishing did not use the explicit Git path separator.")
    try require(!stageArguments.contains("-A") && !stageArguments.contains("."), "Publishing attempted broad Git staging.")
    try require(Array(stageArguments.dropFirst(2)) == parsedChanges.map(\.path).sorted(), "Publishing stage scope did not exactly match preflight.")
    try require(PublishSafetyPolicy.isValidCommitMessage("Update BUS210 course visibility"), "A normal commit message was rejected.")
    try require(!PublishSafetyPolicy.isValidCommitMessage("  \n  "), "A blank or multiline commit message was accepted.")
    try require(!PublishSafetyPolicy.isValidCommitMessage(String(repeating: "x", count: 121)), "An overlong commit message was accepted.")

    let actualPublishingChanges = parsePorcelainStatus(try readGitStatus(at: repositoryRoot))
    let actualUnreviewedPaths = actualPublishingChanges.map(\.path).filter { !PublishSafetyPolicy.allowedPaths.contains($0) }
    try require(actualUnreviewedPaths.isEmpty, "The actual checkout contains unreviewed publishing paths: \(actualUnreviewedPaths.joined(separator: ", "))")
    try require(actualPublishingChanges.allSatisfy { !$0.hasStagedChange && !$0.isConflicted }, "The actual checkout contains staged or conflicted paths.")

    let counts = parseAheadBehind("3\t4")
    try require(counts.ahead == 3 && counts.behind == 4, "Ahead/behind parsing did not preserve Git's left/right counts.")

    print("BUS210 Mission Control core checks passed: repository discovery, actual map load, narrow visibility round-trip, unknown-field preservation, stale-save protection, malformed-data rejection, and publish-scope safety blocks.")
} catch {
    FileHandle.standardError.write(Data("Core checks failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
