import Foundation
import CryptoKit

actor FileHasher {
    private let queue = OperationQueue()

    init() {
        queue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount
    }

    func hash(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.addOperation {
                do {
                    let result = try Self.sha256(url: url)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }

        return hasher.finalize().compactMap { byte in
            String(byte, radix: 16, uppercase: false).padding(toLength: 2, withPad: "0", startingAt: 0)
        }.joined()
    }
}
