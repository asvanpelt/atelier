import Foundation
import Vision

actor FaceClusteringService {
    private let visionRepo: VisionRepository
    private let assetRepo: AssetRepository
    private let visionService: VisionService

    var autoAssignThreshold: Float = 1.5
    var clusterThreshold: Float = 2.5

    init(visionRepo: VisionRepository, assetRepo: AssetRepository, visionService: VisionService) {
        self.visionRepo = visionRepo
        self.assetRepo = assetRepo
        self.visionService = visionService
    }

    struct Progress {
        let stage: String
        let current: Int
        let total: Int
    }

    func backfillEmbeddings(progress: (@Sendable (Progress) -> Void)? = nil) async {
        let pending: [FaceObservation]
        do {
            pending = try await visionRepo.facesNeedingEmbedding()
        } catch {
            Logger.indexing.error("Error fetching faces sin embedding: \(error)")
            return
        }
        let total = pending.count
        for (idx, face) in pending.enumerated() {
            progress?(Progress(stage: "Calculando embeddings", current: idx + 1, total: total))
            await computeEmbedding(for: face)
        }
    }

    func computeEmbedding(for face: FaceObservation) async {
        guard let faceId = face.id else { return }
        do {
            guard let asset = try await assetRepo.find(id: face.assetId) else { return }
            let bbox = (x: face.bboxX, y: face.bboxY, w: face.bboxW, h: face.bboxH)
            if let data = try await visionService.runFaceEmbedding(url: asset.fileURL, bbox: bbox) {
                try await visionRepo.updateEmbedding(id: faceId, data: data)
            }
        } catch {
            Logger.indexing.warning("Error computando embedding cara \(faceId): \(error)")
        }
    }

    /// Reassigns clusters and auto-assigns faces close to existing persons.
    /// Returns (autoAssigned, clusters created/updated).
    @discardableResult
    func reclusterAll(progress: (@Sendable (Progress) -> Void)? = nil) async -> (autoAssigned: Int, clusters: Int) {
        do {
            try await visionRepo.resetClusters()

            let confirmedFaces = try await visionRepo.confirmedFacesWithEmbedding()
            let personCentroids = buildCentroids(confirmedFaces)

            let unassigned = try await visionRepo.facesWithEmbeddingUnassigned()
            let total = unassigned.count

            var nextClusterId = try await visionRepo.nextClusterId()
            var clusterRepresentatives: [(id: Int64, embedding: Data)] = []
            var autoAssigned = 0
            var distanceSamples: [Float] = []

            for (idx, face) in unassigned.enumerated() {
                progress?(Progress(stage: "Agrupando caras", current: idx + 1, total: total))
                guard let faceId = face.id, let embedding = face.embedding else { continue }

                if let (personId, dist) = nearestPerson(embedding: embedding, centroids: personCentroids),
                   dist < autoAssignThreshold {
                    try await visionRepo.confirmFace(id: faceId, personId: personId)
                    autoAssigned += 1
                    continue
                }

                let nearestC = nearestCluster(embedding: embedding, reps: clusterRepresentatives)
                if let nc = nearestC { distanceSamples.append(nc.1) }

                if let (clusterId, dist) = nearestC, dist < clusterThreshold {
                    try await visionRepo.updateCluster(id: faceId, clusterId: clusterId)
                } else {
                    let newCluster = nextClusterId
                    nextClusterId += 1
                    try await visionRepo.updateCluster(id: faceId, clusterId: newCluster)
                    clusterRepresentatives.append((newCluster, embedding))
                }
            }

            if !distanceSamples.isEmpty {
                let sorted = distanceSamples.sorted()
                let minD = sorted.first ?? 0
                let maxD = sorted.last ?? 0
                let mean = sorted.reduce(0, +) / Float(sorted.count)
                let p25 = sorted[sorted.count / 4]
                let p50 = sorted[sorted.count / 2]
                let p75 = sorted[(sorted.count * 3) / 4]
                Logger.indexing.info("Cluster distances — n=\(distanceSamples.count) min=\(String(format: "%.3f", minD)) p25=\(String(format: "%.3f", p25)) p50=\(String(format: "%.3f", p50)) p75=\(String(format: "%.3f", p75)) max=\(String(format: "%.3f", maxD)) mean=\(String(format: "%.3f", mean)) — threshold=\(self.clusterThreshold)")
            }

            return (autoAssigned, clusterRepresentatives.count)
        } catch {
            Logger.indexing.error("Error reclustering: \(error)")
            return (0, 0)
        }
    }

    private func buildCentroids(_ faces: [FaceObservation]) -> [Int64: [Data]] {
        var dict: [Int64: [Data]] = [:]
        for face in faces {
            guard let pid = face.personId, let embedding = face.embedding else { continue }
            dict[pid, default: []].append(embedding)
        }
        return dict
    }

    private func nearestPerson(embedding: Data, centroids: [Int64: [Data]]) -> (Int64, Float)? {
        var best: (Int64, Float)?
        for (pid, samples) in centroids {
            for sample in samples {
                if let d = VisionService.distance(embedding, sample) {
                    if best == nil || d < best!.1 {
                        best = (pid, d)
                    }
                }
            }
        }
        return best
    }

    private func nearestCluster(embedding: Data, reps: [(id: Int64, embedding: Data)]) -> (Int64, Float)? {
        var best: (Int64, Float)?
        for rep in reps {
            if let d = VisionService.distance(embedding, rep.embedding) {
                if best == nil || d < best!.1 {
                    best = (rep.id, d)
                }
            }
        }
        return best
    }
}
