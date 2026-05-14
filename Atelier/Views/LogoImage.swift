import SwiftUI

struct LogoImage: View {
    var size: CGFloat?

    var body: some View {
        if let url = Bundle.module.url(forResource: "logo_trans", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .accessibilityLabel("Atelier logo")
        } else {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: (size ?? 64) * 0.75))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .accessibilityLabel("Atelier")
        }
    }
}
