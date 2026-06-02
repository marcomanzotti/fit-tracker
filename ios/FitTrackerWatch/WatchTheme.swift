import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

// MARK: - Watch visual identity
// A self-contained copy of the phone app's palette and font helpers so the wrist
// looks identical (dark surfaces, Lamborghini-bright yellow accent, rounded stat
// numbers). The phone's Theme/Components import UIKit and can't be shared with
// watchOS, so the small subset the watch needs is mirrored here.

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
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum T {
    static let bg   = Color(hex: "0b0b0d")
    static let c1   = Color(hex: "141417")
    static let c2   = Color(hex: "1f1f23")
    static let c3   = Color(hex: "2a2a30")
    static let brd  = Color(hex: "2a2a30")
    static let acc  = Color(hex: "ffe000")
    static let acc2 = Color(hex: "ffb000")
    static let txt  = Color(hex: "f4efe6")
    static let sub  = Color(hex: "8a857d")
    static let red  = Color(hex: "ff5a52")
    static let blue = Color(hex: "4fb8c4")
    static let good = Color(hex: "7fc950")
    static let radius: CGFloat = 14
}

extension Font {
    static func head(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - SF Symbol per sport (mirrors the phone's Sport.icon)
func sportIcon(_ sport: String?) -> String {
    switch sport {
    case "running":  return "figure.run"
    case "swimming": return "figure.pool.swim"
    case "cycling":  return "figure.outdoor.cycle"
    case "walking":  return "figure.walk"
    case "other":    return "bolt.heart.fill"
    default:         return "dumbbell.fill"   // strength / unknown
    }
}

func watchIcon(for a: WatchActivity) -> String {
    a.kindValue == .strength ? "dumbbell.fill" : sportIcon(a.sport)
}

// MARK: - Haptics
func wkTap() {
    #if canImport(WatchKit)
    WKInterfaceDevice.current().play(.click)
    #endif
}
func wkSuccess() {
    #if canImport(WatchKit)
    WKInterfaceDevice.current().play(.success)
    #endif
}

// MARK: - Small date helper (yyyy-MM-dd, matches the phone)
let wkISO: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()
func wkToday() -> String { wkISO.string(from: Date()) }

func wkClock(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Number parsing / formatting (for strength logging)
/// Parse a number from a free-text field, accepting "," or ".".
func parseNum(_ s: String) -> Double? {
    Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
}
/// First number in a string like "8-10" or "12" -> 8 / 12.
func firstNumber(_ s: String) -> Double? {
    var out = ""
    for ch in s { if ch.isNumber || ch == "." || ch == "," { out.append(ch) } else if !out.isEmpty { break } }
    return parseNum(out)
}
/// Compact numeric string: integer when whole, else one decimal.
func fmtNum(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(format: "%g", (v * 10).rounded() / 10)
}
