import Foundation
import Vision
import AppKit

actor VisionService {

    struct OCRResult {
        let text: String
        let language: String?
    }

    struct ClassificationResult {
        let label: String
        let confidence: Double
    }

    struct FaceResult {
        let bboxX: Double
        let bboxY: Double
        let bboxW: Double
        let bboxH: Double
        let quality: Double?
    }

    func runOCR(url: URL) async throws -> [OCRResult] {
        let image = try loadCGImage(from: url)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [OCRResult] = []
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    if candidate.confidence > 0.3 {
                        results.append(OCRResult(text: candidate.string, language: nil))
                    }
                }
                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es", "en", "fr", "pt", "de", "it"]
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func runClassification(url: URL) async throws -> [ClassificationResult] {
        let image = try loadCGImage(from: url)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(20)
                    .map { ClassificationResult(label: $0.identifier, confidence: Double($0.confidence)) }

                continuation.resume(returning: Array(results))
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func runFaceDetection(url: URL) async throws -> [FaceResult] {
        let image = try loadCGImage(from: url)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.map { obs in
                    let bbox = obs.boundingBox
                    return FaceResult(
                        bboxX: bbox.origin.x,
                        bboxY: bbox.origin.y,
                        bboxW: bbox.width,
                        bboxH: bbox.height,
                        quality: nil
                    )
                }
                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func runFaceEmbedding(url: URL, bbox: (x: Double, y: Double, w: Double, h: Double)) async throws -> Data? {
        let image = try loadCGImage(from: url)
        let pad = 0.15
        let cx = bbox.x + bbox.w / 2
        let cy = bbox.y + bbox.h / 2
        let side = max(bbox.w, bbox.h) * (1 + pad)
        let nx = max(0, cx - side / 2)
        let ny = max(0, cy - side / 2)
        let nw = min(side, 1 - nx)
        let nh = min(side, 1 - ny)

        let cropRect = CGRect(
            x: nx * Double(image.width),
            y: (1 - ny - nh) * Double(image.height),
            width: nw * Double(image.width),
            height: nh * Double(image.height)
        )
        guard let cropped = image.cropping(to: cropRect) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let obs = (request.results as? [VNFeaturePrintObservation])?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: obs, requiringSecureCoding: true)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated static func decodeFeaturePrint(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    nonisolated static func distance(_ a: Data, _ b: Data) -> Float? {
        guard let oa = decodeFeaturePrint(a), let ob = decodeFeaturePrint(b) else { return nil }
        var dist: Float = 0
        do {
            try oa.computeDistance(&dist, to: ob)
            return dist
        } catch {
            return nil
        }
    }

    private func loadCGImage(from url: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw VisionError.invalidImage
        }
        return cgImage
    }
}

enum VisionError: Error {
    case invalidImage
    case processingFailed
}
