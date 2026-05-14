import SwiftUI

@MainActor
@Observable
final class GlassTheme {
    var tintHue: Double {
        didSet { save() }
    }
    var opacity: Double {
        didSet { save() }
    }

    var tintColor: Color {
        Color(hue: tintHue, saturation: 0.65, brightness: 0.95).opacity(opacity)
    }

    init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: "glassTintHue") as? Double, (0...1).contains(saved) {
            tintHue = saved
        } else {
            tintHue = 0.60
        }
        if let saved = defaults.object(forKey: "glassOpacity") as? Double, (0...1).contains(saved) {
            opacity = saved
        } else {
            opacity = 0.12
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(tintHue, forKey: "glassTintHue")
        defaults.set(opacity, forKey: "glassOpacity")
    }
}
