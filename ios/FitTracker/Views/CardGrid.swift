import SwiftUI

/// A static 2-column card grid with a trailing, non-draggable "+" add card that
/// always stays last. Every cell is locked to `rowHeight`, so all cards in the grid
/// share identical dimensions and spacing (strength cards match strength cards;
/// cardio cards match cardio cards).
///
/// Drag-to-reorder was removed deliberately: the home-screen-style live reorder
/// froze the Train page and stole taps from the cards. Stability and tappability
/// matter more than reordering, so this is a plain, reliable grid.
///
/// Generic over the element type `E` (e.g. WorkoutPlan / CardioType). The caller
/// renders each item and the add cell.
struct CardGrid<E: Identifiable, Card: View, Add: View>: View {
    let items: [E]
    let rowHeight: CGFloat
    @ViewBuilder let card: (E) -> Card
    @ViewBuilder let addCell: () -> Add

    private let spacing: CGFloat = 11
    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                card(item).frame(height: rowHeight)
            }
            addCell().frame(height: rowHeight)
        }
    }
}
