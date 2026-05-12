import Foundation

enum AppConstants {
    static let bundleIdentifier = "com.ereerea.atelier"
    static let appName = "Atelier"

    static let appSupportDir: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(appName, isDirectory: true)
    }()

    static let databaseURL: URL = {
        appSupportDir.appendingPathComponent("atelier.db")
    }()

    static let thumbnailsDir: URL = {
        appSupportDir.appendingPathComponent("thumbnails", isDirectory: true)
    }()

    static let organizeTrashDir: URL = {
        appSupportDir.appendingPathComponent("organize-trash", isDirectory: true)
    }()

    static let backupsDir: URL = {
        appSupportDir.appendingPathComponent("backups", isDirectory: true)
    }()

    static let cachesDir: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(appName, isDirectory: true)
    }()
}
