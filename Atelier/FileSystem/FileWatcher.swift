import Foundation

final class FileWatcher: @unchecked Sendable {
    private var pollingTask: Task<Void, Never>?
    private var watchedURLs: [URL] = []
    private var lastCheck: [URL: Date] = [:]
    var onChange: (([URL]) -> Void)?
    let scanInterval: TimeInterval

    init(scanInterval: TimeInterval = 30) {
        self.scanInterval = scanInterval
    }

    func watch(urls: [URL]) {
        stop()
        watchedURLs = urls
        lastCheck = [:]

        pollingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                self.checkForChanges()
                try? await Task.sleep(for: .seconds(self.scanInterval))
            } while !Task.isCancelled
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        watchedURLs = []
    }

    func triggerScan() {
        checkForChanges()
    }

    private func checkForChanges() {
        let fsItems = watchedURLs.flatMap { root in
            allMediaFiles(in: root)
        }

        if !fsItems.isEmpty {
            onChange?(fsItems)
        }
    }

    private func allMediaFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.isImage || fileURL.isVideo else { continue }

            let lastMod: Date? = lastCheck[fileURL]
            let currentMod = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

            if lastMod == nil || currentMod != lastMod {
                files.append(fileURL)
            }
            lastCheck[fileURL] = currentMod
        }

        return files
    }
}
