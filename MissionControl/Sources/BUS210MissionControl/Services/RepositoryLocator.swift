import Foundation

enum RepositoryLocator {
    private static let preferredRepositoryKey = "BUS210PreferredRepositoryPath"

    static func locate(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        var candidates: [URL] = []

        if let configured = environment["BUS210_REPO_ROOT"], !configured.isEmpty {
            candidates.append(URL(fileURLWithPath: configured, isDirectory: true))
        }

        if let preferred = userDefaults.string(forKey: preferredRepositoryKey), !preferred.isEmpty {
            candidates.append(URL(fileURLWithPath: preferred, isDirectory: true))
        }

        // Prefer the user's normal GitHub checkout when it contains the maintained
        // course map and workflow. This keeps a Desktop-installed app independent
        // from the worktree where it happened to be built.
        candidates.append(
            homeDirectory
                .appendingPathComponent("Documents/GitHub/BUS210-Finance", isDirectory: true)
        )

        candidates.append(URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
        candidates.append(Bundle.main.bundleURL)
        candidates.append(URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent())

        var visited = Set<String>()
        for candidate in candidates {
            var current = candidate.standardizedFileURL
            for _ in 0..<10 {
                if visited.insert(current.path).inserted, isRepositoryRoot(current, fileManager: fileManager) {
                    return current
                }
                let parent = current.deletingLastPathComponent()
                if parent.path == current.path { break }
                current = parent
            }
        }

        // Codex worktrees are a safe automatic fallback only when exactly one is
        // a complete BUS210 source checkout. If more than one qualifies, the UI
        // asks the user to choose instead of guessing which course map to edit.
        let worktreesRoot = homeDirectory.appendingPathComponent(".codex/worktrees", isDirectory: true)
        let worktreeCandidates = (try? fileManager.contentsOfDirectory(
            at: worktreesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?
            .map { $0.appendingPathComponent("BUS210-Finance", isDirectory: true) }
            .filter { isRepositoryRoot($0, fileManager: fileManager) }
            .sorted { $0.path < $1.path } ?? []

        if worktreeCandidates.count == 1 {
            return worktreeCandidates[0].standardizedFileURL
        }
        return nil
    }

    static func remember(_ repositoryRoot: URL, userDefaults: UserDefaults = .standard) {
        userDefaults.set(repositoryRoot.standardizedFileURL.path, forKey: preferredRepositoryKey)
    }

    static func isRepositoryRoot(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let required = [
            "course-map.json",
            "scripts/build-index.mjs",
            "scripts/validate-course-map.mjs",
        ]
        return required.allSatisfy { fileManager.fileExists(atPath: url.appendingPathComponent($0).path) }
    }
}
