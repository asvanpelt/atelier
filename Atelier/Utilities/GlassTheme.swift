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
        let savedHue = defaults.double(forKey: "glassTintHue")
        tintHue = (0...1).contains(savedHue) && savedHue > 0.001 ? savedHue : 0.60
        let savedOpacity = defaults.double(forKey: "glassOpacity")
        opacity = (0...1).contains(savedOpacity) && savedOpacity > 0.001 ? savedOpacity : 0.12
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(tintHue, forKey: "glassTintHue")
        defaults.set(opacity, forKey: "glassOpacity")
    }
}
