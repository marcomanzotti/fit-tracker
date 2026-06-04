import SwiftUI

/// A 2-column card grid capped at **6 cards per page** (3 rows × 2 columns). The
/// trailing, non-draggable "+" add card always comes right after the last item,
/// on the final page. When there are more items than fit on one page the grid
/// pages horizontally (swipe) and shows small page dots; with ≤6 items it renders
/// exactly as before (a single static page, no dots).
///
/// Every cell is locked to `rowHeight`, so all cards share identical dimensions
/// and spacing (strength cards match strength cards; cardio cards match cardio
/// cards). Drag-to-reorder was removed deliberately (it froze the page and stole
/// taps); this stays a plain, reliable grid.
///
/// Generic over the element type `E` (e.g. WorkoutPlan / CardioType). The caller
/// renders each item and the add cell.
struct CardGrid<E: Identifiable, Card: View, Add: View>: View {
    let items: [E]
    let rowHeight: CGFloat
    @ViewBuilder let card: (E) -> Card
    @ViewBuilder let addCell: () -> Add

    private let spacing: CGFloat = 11
    private let perPage = 6   // 3 rows × 2 columns

    @State private var page = 0

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
    }

    // Cells = every item plus the trailing add cell, chunked into pages of 6.
    // Using indices keeps the add cell as a distinct, last "slot".
    private var totalCells: Int { items.count + 1 }
    private var pageCount: Int { max(1, Int(ceil(Double(totalCells) / Double(perPage)))) }

    var body: some View {
        if pageCount <= 1 {
            // Fast path: one page, identical to the old static grid (no pager).
            gridPage(0)
        } else {
            VStack(spacing: 8) {
                TabView(selection: $page) {
                    ForEach(0..<pageCount, id: \.self) { p in
                        gridPage(p)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .tag(p)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: pageHeight)

                // Page dots — accent for the current page, muted otherwise.
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { p in
                        Circle()
                            .fill(p == page ? Theme.acc : Theme.brd2)
                            .frame(width: p == page ? 7 : 6, height: p == page ? 7 : 6)
                    }
                }
            }
            .onChange(of: items.count) { _ in
                if page >= pageCount { page = max(0, pageCount - 1) }
            }
        }
    }

    // A single page: up to 6 cells. The add cell appears only on the page that
    // holds the slot right after the last item.
    private func gridPage(_ p: Int) -> some View {
        let firstCell = p * perPage
        let lastCell = min(firstCell + perPage, totalCells)   // exclusive
        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(firstCell..<lastCell, id: \.self) { idx in
                if idx < items.count {
                    card(items[idx]).frame(height: rowHeight)
                } else {
                    addCell().frame(height: rowHeight)   // the trailing "+" slot
                }
            }
        }
    }

    // Fixed pager height so swiping between pages doesn't jump: room for 3 rows
    // even when a later page is partly empty.
    private var pageHeight: CGFloat {
        let rows = ceil(Double(perPage) / 2.0)   // 3
        return rowHeight * rows + spacing * (rows - 1)
    }
}
