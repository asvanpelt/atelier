import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
    private(set) var profiles: [Profile] = []
    private(set) var activeProfileID: UUID

    private static let activeKey = "atelier.activeProfileID"
    private let indexURL: URL

    init() {
        self.indexURL = AppConstants.profilesIndexURL
        let loaded = Self.loadProfiles(from: indexURL)

        if loaded.isEmpty {
            let defaultProfile = Profile(name: "Predeterminado", icon: "photo.stack")
            let migrated = Self.migrateLegacyDataIfNeeded(into: defaultProfile)
            self.profiles = [defaultProfile]
            self.activeProfileID = defaultProfile.id
            UserDefaults.standard.set(defaultProfile.id.uuidString, forKey: Self.activeKey)
            Self.saveProfiles([defaultProfile], to: indexURL)
            if migrated {
                Logger.general.info("Datos legados migrados al perfil 'Predeterminado'")
            }
        } else {
            self.profiles = loaded
            if let storedID = UserDefaults.standard.string(forKey: Self.activeKey),
               let uuid = UUID(uuidString: storedID),
               loaded.contains(where: { $0.id == uuid }) {
                self.activeProfileID = uuid
            } else {
                self.activeProfileID = loaded[0].id
                UserDefaults.standard.set(loaded[0].id.uuidString, forKey: Self.activeKey)
            }
        }
    }

    var activeProfile: Profile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    func create(name: String, icon: String = "photo.stack") -> Profile {
        let profile = Profile(name: name, icon: icon)
        profiles.append(profile)
        persist()
        try? FileManager.default.createDirectory(
            at: AppConstants.profileDir(for: profile.id),
            withIntermediateDirectories: true
        )
        return profile
    }

    func rename(_ id: UUID, to newName: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].name = newName
        persist()
    }

    func updateIcon(_ id: UUID, to icon: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].icon = icon
        persist()
    }

    func delete(_ id: UUID) throws {
        guard profiles.count > 1 else {
            throw ProfileError.cannotDeleteLast
        }
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        let dir = AppConstants.profileDir(for: id)
        try? FileManager.default.removeItem(at: dir)
        profiles.remove(at: idx)
        if activeProfileID == id {
            activeProfileID = profiles[0].id
            UserDefaults.standard.set(activeProfileID.uuidString, forKey: Self.activeKey)
        }
        persist()
    }

    func setActive(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.activeKey)
    }

    private func persist() {
        Self.saveProfiles(profiles, to: indexURL)
    }

    private static func loadProfiles(from url: URL) -> [Profile] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Profile].self, from: data)) ?? []
    }

    private static func saveProfiles(_ profiles: [Profile], to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func migrateLegacyDataIfNeeded(into profile: Profile) -> Bool {
        let fm = FileManager.default
        let base = AppConstants.baseAppSupportDir
        let legacyDB = base.appendingPathComponent("atelier.db")
        let legacyDBWAL = base.appendingPathComponent("atelier.db-wal")
        let legacyDBSHM = base.appendingPathComponent("atelier.db-shm")
        let legacyThumbs = base.appendingPathComponent("thumbnails")
        let legacyOrganize = base.appendingPathComponent("organize-trash")
        let legacyBackups = base.appendingPathComponent("backups")

        let hasLegacy = fm.fileExists(atPath: legacyDB.path)
            || fm.fileExists(atPath: legacyThumbs.path)
        guard hasLegacy else { return false }

        let profileDir = AppConstants.profileDir(for: profile.id)
        try? fm.createDirectory(at: profileDir, withIntermediateDirectories: true)

        let moves: [(URL, URL)] = [
            (legacyDB, profileDir.appendingPathComponent("atelier.db")),
            (legacyDBWAL, profileDir.appendingPathComponent("atelier.db-wal")),
            (legacyDBSHM, profileDir.appendingPathComponent("atelier.db-shm")),
            (legacyThumbs, profileDir.appendingPathComponent("thumbnails")),
            (legacyOrganize, profileDir.appendingPathComponent("organize-trash")),
            (legacyBackups, profileDir.appendingPathComponent("backups")),
        ]

        for (src, dst) in moves where fm.fileExists(atPath: src.path) {
            do {
                try fm.moveItem(at: src, to: dst)
            } catch {
                if (try? fm.copyItem(at: src, to: dst)) != nil {
                    try? fm.removeItem(at: src)
                }
            }
        }
        return true
    }
}

enum ProfileError: LocalizedError {
    case cannotDeleteLast

    var errorDescription: String? {
        switch self {
        case .cannotDeleteLast:
            return "No puedes eliminar el último perfil."
        }
    }
}
