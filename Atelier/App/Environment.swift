import Foundation

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    var database: Database?

    private init() {}
}
