import SwiftUI

struct PersonPhotosSheet: View {
    let person: Person
    let assets: [Asset]
    let thumbnailService: ThumbnailService
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 14)]
    private let tileSize: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.title3.weight(.semibold))
                    Text("\(assets.count) foto\(assets.count == 1 ? "" : "s") relacionada\(assets.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button("Cerrar", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if assets.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Sin fotos relacionadas",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Esta persona aún no tiene caras confirmadas en ninguna foto.")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(assets, id: \.id) { asset in
                            AssetThumbnailTile(
                                asset: asset,
                                thumbnailService: thumbnailService,
                                size: tileSize
                            )
                            .contextMenu {
                                Button("Mostrar en Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 720, idealWidth: 880, minHeight: 480, idealHeight: 600)
    }
}
