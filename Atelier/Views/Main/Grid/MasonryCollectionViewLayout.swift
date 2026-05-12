import AppKit

final class MasonryCollectionViewLayout: NSCollectionViewLayout, @unchecked Sendable {
    var cellWidth: CGFloat = 200
    var spacing: CGFloat = 4
    var sectionInset: NSEdgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    var items: [Asset] = [] {
        didSet { invalidateLayout() }
    }

    private var cache: [NSCollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    private func heightForItem(at index: Int, columnWidth: CGFloat) -> CGFloat {
        guard index < items.count else { return columnWidth }
        let asset = items[index]
        if let w = asset.width, let h = asset.height, w > 0, h > 0 {
            return columnWidth * CGFloat(h) / CGFloat(w)
        }
        if asset.mediaType == .video {
            return columnWidth * 0.5625
        }
        return columnWidth
    }

    override var collectionViewContentSize: NSSize {
        guard let collectionView else { return .zero }
        return NSSize(width: collectionView.bounds.width, height: contentHeight)
    }

    override func prepare() {
        cache.removeAll()
        guard let collectionView, collectionView.numberOfSections > 0 else {
            contentHeight = 0
            return
        }

        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            contentHeight = 0
            return
        }

        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let numberOfColumns = max(1, Int((availableWidth + spacing) / (cellWidth + spacing)))
        let columnWidth = (availableWidth - spacing * CGFloat(numberOfColumns - 1)) / CGFloat(numberOfColumns)

        var columnHeights = Array(repeating: sectionInset.top, count: numberOfColumns)
        var xOffsets: [CGFloat] = []
        for col in 0..<numberOfColumns {
            xOffsets.append(sectionInset.left + CGFloat(col) * (columnWidth + spacing))
        }

        for item in 0..<itemCount {
            let shortestColumn = columnHeights.firstIndex(of: columnHeights.min()!)!
            let x = xOffsets[shortestColumn]
            let height = heightForItem(at: item, columnWidth: columnWidth)
            let y = columnHeights[shortestColumn]

            let frame = NSRect(x: x, y: y, width: columnWidth, height: height)
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            attributes.frame = frame
            cache.append(attributes)
            columnHeights[shortestColumn] = y + height + spacing
        }

        contentHeight = (columnHeights.max() ?? 0) + sectionInset.bottom
    }

    override func invalidateLayout(with context: NSCollectionViewLayoutInvalidationContext) {
        cache.removeAll()
        super.invalidateLayout(with: context)
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        guard indexPath.item < cache.count else { return nil }
        return cache[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}
