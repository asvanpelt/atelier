import SwiftUI
import AppKit

struct AssetGridView: NSViewRepresentable {
    @Binding var assets: [Asset]
    var cellSize: CGFloat
    var isBlurred: Bool
    var onSelect: ((Asset) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = createLayout(size: cellSize)
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(AssetCell.self, forItemWithIdentifier: AssetCell.identifier)
        collectionView.setDraggingSourceOperationMask(.copy, forLocal: false)

        scrollView.documentView = collectionView
        context.coordinator.collectionView = collectionView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let assetsChanged = coordinator.assets.count != assets.count ||
            coordinator.assets.first?.id != assets.first?.id

        coordinator.assets = assets
        coordinator.onSelect = onSelect
        coordinator.isBlurred = isBlurred

        if coordinator.currentCellSize != cellSize {
            coordinator.currentCellSize = cellSize
            if let cv = coordinator.collectionView {
                cv.collectionViewLayout = createLayout(size: cellSize)
            }
        }

        if assetsChanged {
            coordinator.collectionView?.reloadData()
        } else if let cv = coordinator.collectionView {
            for (index, item) in cv.visibleItems().enumerated() {
                if let cell = item as? AssetCell, index < assets.count {
                    cell.isBlurred = isBlurred
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(assets: assets, onSelect: onSelect, isBlurred: isBlurred, cellSize: cellSize)
    }

    private func createLayout(size: CGFloat) -> NSCollectionViewFlowLayout {
        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        layout.sectionInset = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        layout.itemSize = NSSize(width: size, height: size)
        layout.scrollDirection = .vertical
        return layout
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var assets: [Asset]
        var onSelect: ((Asset) -> Void)?
        var isBlurred: Bool
        var currentCellSize: CGFloat
        weak var collectionView: NSCollectionView?

        init(assets: [Asset], onSelect: ((Asset) -> Void)?, isBlurred: Bool, cellSize: CGFloat) {
            self.assets = assets
            self.onSelect = onSelect
            self.isBlurred = isBlurred
            self.currentCellSize = cellSize
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            assets.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: AssetCell.identifier, for: indexPath)
            if let cell = item as? AssetCell, indexPath.item < assets.count {
                cell.isBlurred = isBlurred
                cell.configure(with: assets[indexPath.item])
            }
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let indexPath = indexPaths.first, indexPath.item < assets.count else { return }
            onSelect?(assets[indexPath.item])
        }
    }
}
