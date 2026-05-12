import SwiftUI

struct WelcomeView: View {
    var onAddFolder: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            LogoImage(size: 80)

            Text("Bienvenido a Atelier")
                .font(.largeTitle.bold())

            Text("Tu biblioteca multimedia local.\nAtelier indexa tus archivos sin moverlos de su ubicación original.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            VStack(spacing: 12) {
                featureRow(icon: "folder.badge.plus", title: "Agregá carpetas", description: "Seleccioná las carpetas que querés indexar")
                featureRow(icon: "magnifyingglass", title: "Buscá rápido", description: "Encontrá archivos por nombre al instante")
                featureRow(icon: "photo.stack", title: "Previsualizá", description: "Miniaturas de imágenes y videos en un grid")
            }
            .frame(maxWidth: 360)

            Spacer()

            HStack(spacing: 16) {
                Button("Omitir") {
                    onSkip()
                }
                .buttonStyle(.bordered)

                Button(action: onAddFolder) {
                    Label("Agregar carpeta...", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer().frame(height: 20)
        }
        .frame(width: 500, height: 480)
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
