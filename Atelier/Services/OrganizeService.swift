import Foundation

enum OrganizeTemplate: String, CaseIterable, Identifiable {
    case sourceAccountYear
    case typeAndTag

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sourceAccountYear: return "Origen → cuenta → año"
        case .typeAndTag: return "Tipo → tag"
        }
    }

    var description: String {
        switch self {
        case .sourceAccountYear: return "Ej: Instagram/elixserr/2026/foo.jpg · sin clasificar van a 'Sin clasificar/AAAA/'"
        case .typeAndTag: return "Ej: Imágenes/paisaje/foo.jpg · sin tag van a 'Imágenes/Sin tag/'"
        }
    }
}

struct OrganizeFilter: Equatable {
    var includeImages: Bool = true
    var includeVideos: Bool = true
    var onlyWithSource: Bool = false
    var onlyWithoutSource: Bool = false

    func apply(_ assets: [Asset]) -> [Asset] {
        assets.filter { a in
            switch a.mediaType {
            case .image where !includeImages: return false
            case .video where !includeVideos: return false
            default: break
            }
            if onlyWithSource && a.source == nil { return false }
            if onlyWithoutSource && a.source != nil { return false }
            return true
        }
    }
}

struct OrganizePlanItem: Identifiable {
    let id = UUID()
    let asset: Asset
    let sourcePath: String
    let destinationPath: String
    let conflict: Bool
    var selected: Bool
}

struct OrganizeRunSummary {
    let total: Int
    let succeeded: Int
    let failed: Int
    let runId: Int64?
}

actor OrganizeService {
    private let assetRepo: AssetRepository
    private let tagRepo: TagRepository
    private let db: Database

    init(assetRepo: AssetRepository, tagRepo: TagRepository, db: Database) {
        self.assetRepo = assetRepo
        self.tagRepo = tagRepo
        self.db = db
    }

    // MARK: - Plan

    func buildPlan(
        template: OrganizeTemplate,
        destinationRoot: URL,
        filter: OrganizeFilter
    ) async throws -> [OrganizePlanItem] {
        let allAssets = try await assetRepo.findAll()
        let assets = filter.apply(allAssets)

        var tagsCache: [Int64: [Tag]] = [:]
        if template == .typeAndTag {
            for asset in assets {
                guard let id = asset.id else { continue }
                let entries = try await tagRepo.tagsFor(assetId: id)
                tagsCache[id] = entries.map(\.tag)
            }
        }

        let fm = FileManager.default
        var plan: [OrganizePlanItem] = []
        var plannedDestinations = Set<String>()

        for asset in assets {
            let dst = destinationPath(for: asset, template: template, root: destinationRoot, tags: tagsCache[asset.id ?? -1] ?? [])
            let dstPath = dst.path
            if asset.filePath == dstPath { continue }

            let conflict = fm.fileExists(atPath: dstPath) || plannedDestinations.contains(dstPath)
            plannedDestinations.insert(dstPath)

            plan.append(OrganizePlanItem(
                asset: asset,
                sourcePath: asset.filePath,
                destinationPath: dstPath,
                conflict: conflict,
                selected: !conflict
            ))
        }

        return plan.sorted { $0.destinationPath < $1.destinationPath }
    }

    private func destinationPath(for asset: Asset, template: OrganizeTemplate, root: URL, tags: [Tag]) -> URL {
        let filename = (asset.filePath as NSString).lastPathComponent
        let cal = Calendar(identifier: .gregorian)
        let year = String(cal.component(.year, from: asset.createdAt))

        switch template {
        case .sourceAccountYear:
            if let sourceRaw = asset.source, let kind = AssetSource(rawValue: sourceRaw) {
                let folder = sanitize(kind.label)
                let account = asset.sourceAccount.map(sanitize) ?? "_general"
                return root
                    .appendingPathComponent(folder, isDirectory: true)
                    .appendingPathComponent(account, isDirectory: true)
                    .appendingPathComponent(year, isDirectory: true)
                    .appendingPathComponent(filename)
            } else {
                return root
                    .appendingPathComponent("Sin clasificar", isDirectory: true)
                    .appendingPathComponent(year, isDirectory: true)
                    .appendingPathComponent(filename)
            }

        case .typeAndTag:
            let typeFolder: String
            switch asset.mediaType {
            case .image: typeFolder = "Imágenes"
            case .video: typeFolder = "Videos"
            case .unknown: typeFolder = "Otros"
            }
            let tagFolder: String
            if let firstTag = tags.first {
                tagFolder = sanitize(firstTag.displayName)
            } else {
                tagFolder = "Sin tag"
            }
            return root
                .appendingPathComponent(typeFolder, isDirectory: true)
                .appendingPathComponent(tagFolder, isDirectory: true)
                .appendingPathComponent(filename)
        }
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    // MARK: - Apply

    func apply(_ items: [OrganizePlanItem], template: OrganizeTemplate) async -> OrganizeRunSummary {
        let toRun = items.filter { $0.selected && !$0.conflict }
        let total = toRun.count
        guard total > 0 else { return OrganizeRunSummary(total: 0, succeeded: 0, failed: 0, runId: nil) }

        let runId: Int64?
        do {
            runId = try await insertRun(template: template, total: total)
        } catch {
            Logger.indexing.error("Error creando organize_run: \(error)")
            return OrganizeRunSummary(total: total, succeeded: 0, failed: total, runId: nil)
        }

        var succeeded = 0
        var failed = 0
        let fm = FileManager.default

        for item in toRun {
            guard let assetId = item.asset.id else { failed += 1; continue }
            let dst = URL(fileURLWithPath: item.destinationPath)
            let src = URL(fileURLWithPath: item.sourcePath)

            do {
                try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)

                if fm.fileExists(atPath: dst.path) {
                    throw NSError(domain: "Organize", code: 1, userInfo: [NSLocalizedDescriptionKey: "Destino ya existe"])
                }

                try fm.moveItem(at: src, to: dst)

                try await assetRepo.updatePath(id: assetId, newPath: dst.path)
                try await insertOperation(runId: runId, assetId: assetId, src: src.path, dst: dst.path, status: "applied", error: nil)
                try await insertPathHistory(assetId: assetId, path: dst.path)
                succeeded += 1
            } catch {
                Logger.indexing.error("Error moviendo \(src.path) → \(dst.path): \(error)")
                try? await insertOperation(runId: runId, assetId: assetId, src: src.path, dst: dst.path, status: "failed", error: error.localizedDescription)
                failed += 1
            }
        }

        try? await finalizeRun(id: runId, succeeded: succeeded, failed: failed)
        return OrganizeRunSummary(total: total, succeeded: succeeded, failed: failed, runId: runId)
    }

    // MARK: - DB helpers

    private func insertRun(template: OrganizeTemplate, total: Int) async throws -> Int64 {
        let pool = try db.pool
        return try await pool.write { db in
            try db.execute(sql: """
                INSERT INTO organize_runs (rule_id, mode, started_at, status, total_assets)
                VALUES (NULL, ?, ?, 'running', ?)
                """, arguments: [template.rawValue, Int(Date().timeIntervalSince1970), total])
            return db.lastInsertedRowID
        }
    }

    private func finalizeRun(id: Int64?, succeeded: Int, failed: Int) async throws {
        guard let id else { return }
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(sql: """
                UPDATE organize_runs
                SET finished_at = ?, status = 'completed', succeeded = ?, failed = ?
                WHERE id = ?
                """, arguments: [Int(Date().timeIntervalSince1970), succeeded, failed, id])
        }
    }

    private func insertOperation(runId: Int64?, assetId: Int64, src: String, dst: String, status: String, error: String?) async throws {
        guard let runId else { return }
        let pool = try db.pool
        try await pool.write { db in
            try db.execute(sql: """
                INSERT INTO organize_operations
                (run_id, asset_id, operation_type, source_path, destination_path, status, error, applied_at)
                VALUES (?, ?, 'move', ?, ?, ?, ?, ?)
                """, arguments: [runId, assetId, src, dst, status, error, Int(Date().timeIntervalSince1970)])
        }
    }

    private func insertPathHistory(assetId: Int64, path: String) async throws {
        let pool = try db.pool
        try await pool.write { db in
            let now = Int(Date().timeIntervalSince1970)
            try db.execute(sql: """
                UPDATE asset_path_history SET valid_to = ? WHERE asset_id = ? AND valid_to IS NULL
                """, arguments: [now, assetId])
            try db.execute(sql: """
                INSERT INTO asset_path_history (asset_id, path, valid_from, changed_by)
                VALUES (?, ?, ?, 'organize')
                """, arguments: [assetId, path, now])
        }
    }
}
