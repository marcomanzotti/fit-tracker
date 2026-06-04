package com.marco.fittracker.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.clip
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlin.math.ceil

/**
 * A 2-column card grid capped at **6 cards per page** (3 rows x 2 columns). The
 * trailing "add" card always comes right after the last item, on the final page.
 * When the items + add card fit on one page it renders as a plain static grid
 * (no pager, no dots) — identical to the old layout. Past 6, it pages
 * horizontally (swipe) with small page dots, mirroring the iOS CardGrid.
 *
 * [items] are the data cards; [card] renders one item and [addCard] renders the
 * trailing "+" cell. Generic over the element type [E].
 */
@Composable
fun <E> CardPager(
    items: List<E>,
    card: @Composable (E) -> Unit,
    addCard: @Composable () -> Unit,
) {
    val perPage = 6
    val totalCells = items.size + 1            // items + the add card
    val pageCount = maxOf(1, ceil(totalCells / perPage.toDouble()).toInt())

    if (pageCount <= 1) {
        GridPage(0, perPage, items, card, addCard)
        return
    }

    val state = rememberPagerState(pageCount = { pageCount })
    Column {
        HorizontalPager(state = state) { page ->
            GridPage(page, perPage, items, card, addCard)
        }
        Spacer(Modifier.height(8.dp))
        // Page dots — accent for the current page, muted otherwise.
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)
        ) {
            for (p in 0 until pageCount) {
                Box(
                    Modifier.size(if (p == state.currentPage) 7.dp else 6.dp)
                        .clip(CircleShape)
                        .background(if (p == state.currentPage) T.acc else T.brd2)
                )
            }
        }
    }
}

/** One page: up to 6 cells laid out as 3 rows x 2 columns. The add card shows
 *  only on the page that holds the slot right after the last item. */
@Composable
private fun <E> GridPage(
    page: Int,
    perPage: Int,
    items: List<E>,
    card: @Composable (E) -> Unit,
    addCard: @Composable () -> Unit,
) {
    val totalCells = items.size + 1
    val first = page * perPage
    val last = minOf(first + perPage, totalCells)   // exclusive
    val rows = perPage / 2                            // 3
    Column(verticalArrangement = Arrangement.spacedBy(11.dp)) {
        for (r in 0 until rows) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                for (c in 0 until 2) {
                    val idx = first + r * 2 + c
                    Box(Modifier.weight(1f)) {
                        if (idx in first until last) {
                            if (idx < items.size) card(items[idx]) else addCard()
                        }
                    }
                }
            }
        }
    }
}
