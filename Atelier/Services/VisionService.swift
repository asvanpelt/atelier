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
