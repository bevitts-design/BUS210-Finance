import Foundation

@MainActor
final class PublishStore: ObservableObject {
    @Published private(set) var preflight: PublishPreflight?
    @Published private(set) var result: PublishResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var activityLabel: String?
    @Published var commitMessage = "Update BUS210 course site and Mission Control"
    @Published var showsConfirmation = false

    private let service: GitPublishService

    init(service: GitPublishService = .init()) {
        self.service = service
    }

    func resetForRepositoryChange() {
        preflight = nil
        result = nil
        errorMessage = nil
        activityLabel = nil
        showsConfirmation = false
    }

    func runPreflight(repositoryRoot: URL?) {
        guard let repositoryRoot, !isWorking else {
            if repositoryRoot == nil { errorMessage = "Choose a valid BUS210 repository before running publishing preflight." }
            return
        }
        isWorking = true
        activityLabel = "Fetching origin/main and checking the reviewed scope…"
        errorMessage = nil
        result = nil
        preflight = nil
        Task {
            do {
                preflight = try await service.preflight(repositoryRoot: repositoryRoot)
            } catch {
                errorMessage = error.localizedDescription
            }
            activityLabel = nil
            isWorking = false
        }
    }

    func requestPublish() {
        guard preflight?.canPublish == true, !isWorking else { return }
        showsConfirmation = true
    }

    func confirmPublish(repositoryRoot: URL?) {
        showsConfirmation = false
        guard let repositoryRoot, let reviewedPreflight = preflight, reviewedPreflight.canPublish, !isWorking else { return }
        isWorking = true
        activityLabel = "Rebuilding, validating, committing, and pushing main…"
        errorMessage = nil
        result = nil
        Task {
            do {
                result = try await service.publish(
                    repositoryRoot: repositoryRoot,
                    reviewedPreflight: reviewedPreflight,
                    commitMessage: commitMessage
                )
                preflight = nil
            } catch let failure as PublishOperationError {
                result = failure.result
                errorMessage = failure.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            activityLabel = nil
            isWorking = false
        }
    }
}
