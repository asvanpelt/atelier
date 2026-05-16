import Foundation

enum AppConstants {
    static let bundleIdentifier = "com.ereerea.atelier"
    static let appName = "Atelier"

    static var baseAppSupportDir: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(appName, isDirectory: true)
    }

    static var baseCachesDir: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(appName, isDirectory: true)
    }

    static var profilesIndexURL: URL {
        baseAppSupportDir.appendingPathComponent("profiles.json")
    }

    nonisolated(unsafe) private static var _activeProfileID: UUID?

    static var activeProfileID: UUID {
        guard let id = _activeProfileID else {
            fatalError("AppConstants.activeProfileID accedido antes de inicializar el perfil activo")
        }
        return id
    }

    static func setActiveProfile(_ id: UUID) {
        _activeProfileID = id
    }

    static func profileDir(for id: UUID) -> URL {
        baseAppSupportDir
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static var profileDir: URL { profileDir(for: activeProfileID) }
    static var appSupportDir: URL { profileDir }
    static var databaseURL: URL { profileDir.appendingPathComponent("atelier.db") }
    static var thumbnailsDir: URL { profileDir.appendingPathComponent("thumbnails", isDirectory: true) }
    static var organizeTrashDir: URL { profileDir.appendingPathComponent("organize-trash", isDirectory: true) }
    static var backupsDir: URL { profileDir.appendingPathComponent("backups", isDirectory: true) }
    static var cachesDir: URL { baseCachesDir.appendingPathComponent(activeProfileID.uuidString, isDirectory: true) }
}
