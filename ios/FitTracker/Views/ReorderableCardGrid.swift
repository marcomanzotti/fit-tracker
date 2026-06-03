import SwiftUI

/// A paged 2-column card grid (max 6 cards/page) with long-press drag-to-reorder,
/// like rearranging apps on a Home screen. The backing array is reordered live as
/// you drag, so cards always flow to fill gaps — there are never empty slots, even
/// across pages. A trailing, non-draggable "+" add card is appended automatically
/// and always stays last.
///
/// Generic over the element type `E` (e.g. WorkoutPlan / CardioType). The grid
/// reorders `items` directly through the binding; the caller renders each item and
/// the add cell, and is told when a drop completed (to persist).
///
/// Gesture model: a single long-press *then* drag. We use `.highPriorityGesture`
/// so the long-press wins over any `Button` inside the card (a plain tap still
/// falls through to the button because the long-press never fires for a quick tap).
struct ReorderableCardGrid<E: Identifiable & Equatable, Card: View, Add: View>: View {
    @Binding var items: [E]
    let rowHeight: CGFloat
    let onReorder: () -> Void
    @ViewBuilder let card: (E) -> Card
    @ViewBuilder let addCell: () -> Add

    private let cols = 2
    private let perPage = 6
    private let spacing: CGFloat = 11

    @State private var page = 0
    @State private var dragItem: E.ID?          // the card being dragged
    @State private var dragOffset: CGSize = .zero
    @State private var pageFlipAt: Date = .distantPast

    var body: some View {
        let pageCount = max(1, Int(ceil(Double(items.count + 1) / Double(perPage))))
        let pageHeight = rowHeight * 3 + spacing * 2

        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    gridContent(geo: geo)
                }
                .frame(width: geo.size.width, height: pageHeight, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .frame(height: pageHeight)

            if pageCount > 1 { pageDots(pageCount) }
        }
        .onChange(of: items.count) { _ in
            if page >= pageCount { page = max(0, pageCount - 1) }
        }
    }

    // MARK: Grid

    @ViewBuilder
    private func gridContent(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let cellW = (w - spacing) / CGFloat(cols)
        let cellH = rowHeight
        let start = page * perPage
        let totalCells = items.count + 1                     // +1 for the add card
        let end = min(start + perPage, totalCells)

        ForEach(start..<end, id: \.self) { idx in
            let pos = idx - start
            let col = pos % cols, row = pos / cols
            let x = CGFloat(col) * (cellW + spacing)
            let y = CGFloat(row) * (cellH + spacing)
            cellView(idx: idx, cellW: cellW, cellH: cellH)
                .frame(width: cellW, height: cellH, alignment: .topLeading)
                .offset(x: x, y: y)
                .zIndex(isDragging(idx) ? 10 : 0)
        }
    }

    @ViewBuilder
    private func cellView(idx: Int, cellW: CGFloat, cellH: CGFloat) -> some View {
        if idx < items.count {
            let item = items[idx]
            let dragging = item.id == dragItem
            card(item)
                .frame(width: cellW, height: cellH)
                .scaleEffect(dragging ? 1.04 : 1)
                .shadow(color: .black.opacity(dragging ? 0.4 : 0), radius: dragging ? 12 : 0, y: dragging ? 6 : 0)
                .offset(dragging ? dragOffset : .zero)
                .opacity(dragging ? 0.96 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: items)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: dragging)
                // High priority so the long-press-then-drag beats the inner Button;
                // a quick tap never trips the long press, so taps still fall through.
                .highPriorityGesture(longDrag(for: item, cellW: cellW, cellH: cellH))
        } else {
            addCell()
                .frame(width: cellW, height: cellH)
        }
    }

    private func isDragging(_ idx: Int) -> Bool {
        idx < items.count && items[idx].id == dragItem
    }

    // MARK: Long-press + drag

    private func longDrag(for item: E, cellW: CGFloat, cellH: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("grid")))
            .onChanged { value in
                switch value {
                case .first(true):
                    // Long press recognized — pick the card up.
                    if dragItem != item.id {
                        haptic(.success)
                        dragItem = item.id
                        dragOffset = .zero
                    }
                case .second(true, let drag?):
                    guard dragItem == item.id else { return }
                    dragOffset = drag.translation
                    handleDragMove(point: drag.location, cellW: cellW, cellH: cellH)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard dragItem == item.id else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragItem = nil
                    dragOffset = .zero
                }
                onReorder()
            }
    }

    /// Translate the finger position into a target index and move the dragged card
    /// there, reordering the array live so everything compacts around it.
    private func handleDragMove(point: CGPoint, cellW: CGFloat, cellH: CGFloat) {
        guard let id = dragItem, let from = items.firstIndex(where: { $0.id == id }) else { return }

        // Edge paging: hovering near a horizontal edge flips to the adjacent page
        // (throttled), so a card can travel to another page.
        let edge: CGFloat = 36
        let now = Date()
        let totalCells = items.count + 1
        let pageCount = max(1, Int(ceil(Double(totalCells) / Double(perPage))))
        let gridRight = cellW * 2 + spacing
        if now.timeIntervalSince(pageFlipAt) > 0.6 {
            if point.x > gridRight - edge, page < pageCount - 1 {
                withAnimation { page += 1 }; pageFlipAt = now; tap(); return
            } else if point.x < edge, page > 0 {
                withAnimation { page -= 1 }; pageFlipAt = now; tap(); return
            }
        }

        // Which on-page slot is under the finger → absolute target index.
        let col = max(0, min(cols - 1, Int(point.x / (cellW + spacing))))
        let row = max(0, Int(point.y / (cellH + spacing)))
        let slot = row * cols + col
        var target = page * perPage + slot
        target = max(0, min(items.count - 1, target))       // never past the add card

        if target != from {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                let moved = items.remove(at: from)
                items.insert(moved, at: target)
            }
        }
    }

    // MARK: Page dots

    private func pageDots(_ count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(i == page ? Theme.acc : Theme.brd2)
                    .frame(width: 6, height: 6)
                    .onTapGesture { withAnimation { page = i } }
            }
        }
    }
}
