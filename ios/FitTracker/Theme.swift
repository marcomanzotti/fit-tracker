import SwiftUI

// MARK: - Palette
enum Theme {
    static let bg     = Palette.bg
    static let c1     = Palette.c1
    static let c2     = Palette.c2
    static let c3     = Palette.c3
    static let brd    = Palette.c3
    static let brd2   = Palette.brd2
    static let acc    = Palette.acc
    static let acc2   = Palette.acc2
    static let txt    = Palette.txt
    static let sub    = Palette.sub
    static let mut    = Palette.mut
    static let red    = Palette.red
    static let blue   = Palette.blue
    static let good   = Palette.good
    /// Body-fat accent — a distinct magenta so fat never reads as BMI (purple)
    /// or lean mass (blue) in the body-composition views.
    static let fat    = Palette.fat
    static let purple = Palette.purple
    static let orange = Palette.orange
    /// Apple's workout/exercise-ring green, used to mark sessions imported from
    /// Apple Health (e.g. a watch hike) so they read as "from Apple Health".
    static let appleGreen = "92e82a"

    /// Swatches offered when creating / editing a workout day.
    static let planColors = ["ffe000", "ffb000", "ff5a52", "4fb8c4", "7fc950", "b08fff"]
    /// Separate palette for cardio activity types (kept visually distinct from
    /// the strength-day palette so cardio reads differently on the calendar).
    static let cardioColors = ["4fb8c4", "ff5a52", "7fc950", "b08fff", "ffb000", "53a8ff"]
    /// Full swatch palette offered in the plan / cardio color pickers. Keeps the
    /// loved defaults up front, then adds extra bright hues for customization.
    /// Never includes black or the rest-day off-white, so a sport can't be
    /// confused with an empty or rest slot.
    static let sportColors = [
        "ffe000", "ffb000", "ff8a3d", "ff5a52", "e0556b", "ff5da2", "c47cff",
        "b08fff", "53a8ff", "4fb8c4", "3dd6c4", "7fc950", "b6e64a", "2ecc8f"
    ]

    static let radius:  CGFloat = 18
    static let radiusS: CGFloat = 12
    /// Apple's minimum comfortable touch target.
    static let minTapTarget: CGFloat = 44
    /// The one spring used for UI that settles into place: quick, no overshoot.
    static let settle = Animation.spring(response: 0.35, dampingFraction: 1)

    /// Shared visual identity for a "rest" day, used identically on the weekly
    /// plan and the "this week" strip and calendar: an almost-white chip with a
    /// dark moon/zzz icon (mirrors how a trained day shows a dark dumbbell).
    static let restFill = Color(hex: "ece7dc")     // almost white
    static let restIcon = "moon.zzz.fill"
}
