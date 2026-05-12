import SwiftUI

extension View {
    func glassOverlay(tint: Color) -> some View {
        overlay(
            Rectangle()
                .fill(tint)
                .allowsHitTesting(false)
        )
    }
}
