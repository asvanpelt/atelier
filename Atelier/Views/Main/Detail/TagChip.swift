import SwiftUI

struct TagChip: View {
    let tag: Tag
    let source: String
    let confidence: Double?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Text(tag.displayName)
            if source != TagSource.manual.rawValue {
                Image(systemName: "sparkles")
                    .font(.caption)
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chipColor)
        .clipShape(.rect(cornerRadius: 4))
    }

    private var chipColor: Color {
        let c = tag.displayColor
        if source == TagSource.manual.rawValue || (confidence ?? 0) > 0.9 {
            return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness).opacity(0.3)
        }
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness).opacity(0.15)
    }
}
