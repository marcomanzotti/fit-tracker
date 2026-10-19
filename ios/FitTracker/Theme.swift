import SwiftUI

// MARK: - Palette
enum Theme {
    static let bg     = Color(hex: "0b0b0d")
    static let c1     = Color(hex: "141417")
    static let c2     = Color(hex: "1f1f23")
    static let c3     = Color(hex: "2a2a30")
    static let brd    = Color(hex: "2a2a30")
    static let brd2   = Color(hex: "3a3a42")
    static let acc    = Color(hex: "ffe000")   // Lamborghini-bright yellow (was ffd21e)
    static let acc2   = Color(hex: "ffb000")
    static let txt    = Color(hex: "f4efe6")
    static let sub    = Color(hex: "9a958d")   // 5.2:1 on the card surface (AA)
    static let mut    = Color(hex: "161619")
    static let red    = Color(hex: "ff5a52")
    static let blue   = Color(hex: "4fb8c4")
    static let good   = Color(hex: "7fc950")
    /// Body-fat accent — a distinct magenta so fat never reads as BMI (purple)
    /// or lean mass (blue) in the body-composition views.
    static let fat    = Color(hex: "ff5da2")
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
