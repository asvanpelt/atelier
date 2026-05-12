import Foundation

final class Debouncer: @unchecked Sendable {
    private let delay: TimeInterval
    private var task: Task<Void, Never>?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func run(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task { [delay] in
            do {
                try await Task.sleep(for: .seconds(delay))
                if !Task.isCancelled {
                    await action()
                }
            } catch {
                // cancelled
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
