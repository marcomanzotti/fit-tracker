import SwiftUI

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 3:  (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 8:  (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24 & 0xFF)
        default: (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

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
    static let accDim = Color(hex: "c25200")
    static let txt    = Color(hex: "f4efe6")
    static let sub    = Color(hex: "8a857d")
    static let mut    = Color(hex: "161619")
    static let red    = Color(hex: "ff5a52")
    static let blue   = Color(hex: "4fb8c4")
    static let good   = Color(hex: "7fc950")

    /// Swatches offered when creating / editing a workout day.
    static let planColors = ["ffe000", "ffb000", "ff5a52", "4fb8c4", "7fc950", "b08fff"]
    /// Separate palette for cardio activity types (kept visually distinct from
    /// the strength-day palette so cardio reads differently on the calendar).
    static let cardioColors = ["4fb8c4", "ff5a52", "7fc950", "b08fff", "ffb000", "53a8ff"]

    static let radius:  CGFloat = 18
    static let radiusS: CGFloat = 12
    static let radiusXS: CGFloat = 9

    /// Shared visual identity for a "rest" day, used identically on the weekly
    /// plan and the "this week" strip and calendar: an almost-white chip with a
    /// dark moon/zzz icon (mirrors how a trained day shows a dark dumbbell).
    static let restFill = Color(hex: "ece7dc")     // almost white
    static let restIcon = "moon.zzz.fill"
}

// MARK: - Fonts (system fonts emulating the original Oswald / Archivo look)
extension Font {
    /// Heading / label font — used uppercase with tracking.
    static func head(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    /// Numeric font — rounded design for the big stat numbers.
    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
