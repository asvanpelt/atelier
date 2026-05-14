import Foundation

enum AssetSource: String, CaseIterable {
    case instagram
    case instagramCdn = "instagram_cdn"
    case tiktok
    case twitter
    case whatsapp
    case screenshotMac = "screenshot_mac"
    case screenshotAndroid = "screenshot_android"
    case gemini
    case unknown

    var label: String {
        switch self {
        case .instagram, .instagramCdn: return "Instagram"
        case .tiktok: return "TikTok"
        case .twitter: return "Twitter / X"
        case .whatsapp: return "WhatsApp"
        case .screenshotMac: return "Captura de pantalla (Mac)"
        case .screenshotAndroid: return "Captura / Cámara"
        case .gemini: return "Gemini AI"
        case .unknown: return "Desconocido"
        }
    }

    var symbol: String {
        switch self {
        case .instagram, .instagramCdn: return "camera.fill"
        case .tiktok: return "music.note.tv.fill"
        case .twitter: return "bird.fill"
        case .whatsapp: return "message.fill"
        case .screenshotMac: return "macwindow"
        case .screenshotAndroid: return "iphone"
        case .gemini: return "sparkles"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct SourceDetectionResult: Equatable {
    let source: AssetSource
    let account: String?
}

enum SourceDetector {
    private nonisolated(unsafe) static let instagramDownloader = #/^_*(?<account>[A-Za-z0-9._]+?)_*__\d{4}-\d{2}-\d{2}T\d{6}\.\d{3}Z(_\d+)?(\(\d+\))?\.[A-Za-z0-9]+$/#
    private nonisolated(unsafe) static let instagramCdn = #/^\d{8,}_\d{8,}_\d{8,}_n\.(?i)(jpg|jpeg|png|webp|mp4)$/#
    private nonisolated(unsafe) static let twitter = #/^[A-Za-z0-9_-]{15}\.(?i)(jpg|jpeg|png|webp)$/#
    private nonisolated(unsafe) static let tiktok = #/^(?i)(tiktok_|tt_)/#
    private nonisolated(unsafe) static let whatsapp = #/^WhatsApp (Image|Video|Audio) /#
    private nonisolated(unsafe) static let screenshotMac = #/^(Captura de pantalla|Screenshot|Screen Shot) /#
    private nonisolated(unsafe) static let screenshotAndroid = #/^(IMG_|VID_|PXL_|Screenshot_)?\d{8}[_-]\d{6}/#
    private nonisolated(unsafe) static let gemini = #/^Gemini_Generated_/#

    static func detect(filename: String) -> SourceDetectionResult {
        let name = (filename as NSString).lastPathComponent

        if let m = try? instagramDownloader.wholeMatch(in: name) {
            let account = String(m.account)
            return SourceDetectionResult(source: .instagram, account: account.isEmpty ? nil : account)
        }
        if (try? instagramCdn.wholeMatch(in: name)) != nil {
            return SourceDetectionResult(source: .instagramCdn, account: nil)
        }
        if (try? twitter.wholeMatch(in: name)) != nil {
            return SourceDetectionResult(source: .twitter, account: nil)
        }
        if (try? tiktok.firstMatch(in: name)) != nil {
            return SourceDetectionResult(source: .tiktok, account: nil)
        }
        if (try? whatsapp.firstMatch(in: name)) != nil {
            return SourceDetectionResult(source: .whatsapp, account: nil)
        }
        if (try? screenshotMac.firstMatch(in: name)) != nil {
            return SourceDetectionResult(source: .screenshotMac, account: nil)
        }
        if (try? gemini.firstMatch(in: name)) != nil {
            return SourceDetectionResult(source: .gemini, account: nil)
        }
        if (try? screenshotAndroid.firstMatch(in: name)) != nil {
            return SourceDetectionResult(source: .screenshotAndroid, account: nil)
        }

        return SourceDetectionResult(source: .unknown, account: nil)
    }
}
