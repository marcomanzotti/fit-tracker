import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(HealthKit)
import HealthKit
#endif

// Colour, font and formatting helpers shared by the phone app, the watch app and
// the widgets, so the three look the same and the definitions exist once.

// MARK: - Numbers
/// No weight, rep count, distance or duration in this app comes near this.
private let maxParsedMagnitude = 1e9

/// A number typed or received as text, accepting "," or "."; nil when it is not a
/// plain, sane number. "inf", "nan" and absurd magnitudes would otherwise break JSON
/// encoding (and so every later save) or trap in an `Int(...)` conversion.
func parsedNumber(_ s: String) -> Double? {
    guard let v = Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)),
          v.isFinite, abs(v) < maxParsedMagnitude else { return nil }
    return v
}

/// `parsedNumber`, with 0 for anything that is not a number (mirrors the web app's pf()).
func pf(_ s: String) -> Double { parsedNumber(s) ?? 0 }

/// Rounded to an Int, 0 when the value is not finite or out of range: `Int(_:)` traps there.
func safeInt(_ v: Double) -> Int {
    guard v.isFinite, abs(v) < maxParsedMagnitude else { return 0 }
    return Int(v.rounded())
}

func trimNum(_ v: Double) -> String {
    guard v.isFinite else { return "—" }
    // Int(v) traps outside Int's range, so only whole numbers well inside it.
    if v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
    return String(format: "%g", v)
}

/// "1.0 · 412 · 9d1b60e": version, build number (commit count) and commit, set by
/// build_and_run.py. A build from the Xcode IDE shows only version and build.
var appVersionLabel: String {
    let info = Bundle.main.infoDictionary ?? [:]
    let parts = [info["CFBundleShortVersionString"], info["CFBundleVersion"], info["FTGitHash"]]
        .compactMap { $0 as? String }.filter { !$0.isEmpty && !$0.hasPrefix("$(") }
    return parts.joined(separator: " · ")
}
// MARK: - Dates and clocks
/// yyyy-MM-dd, the day format of every stored date (phone, watch, widget).
let isoFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func today() -> String { isoFormatter.string(from: Date()) }

/// Seconds as a running clock: "4:05", or "1:04:05" past the hour.
func fmtClock(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Sports
/// SF Symbol of a sport (the Sport raw value); strength when unknown.
func sportSymbol(_ sport: String?) -> String {
    switch sport {
    case "running":  return "figure.run"
    case "swimming": return "figure.pool.swim"
    case "cycling":  return "figure.outdoor.cycle"
    case "walking":  return "figure.walk"
    case "other":    return "bolt.heart.fill"
    default:         return "dumbbell.fill"
    }
}

#if canImport(HealthKit)
/// The HealthKit activity a sport is written as.
func hkActivityType(sport: String?) -> HKWorkoutActivityType {
    switch sport {
    case "strength": return .traditionalStrengthTraining
    case "running":  return .running
    case "cycling":  return .cycling
    case "swimming": return .swimming
    case "walking":  return .walking
    default:         return .other
    }
}

/// Which distance a sport records (nil when distance means nothing for it).
func hkDistanceIdentifier(sport: String?) -> HKQuantityTypeIdentifier? {
    switch sport {
    case "running", "walking": return .distanceWalkingRunning
    case "cycling":            return .distanceCycling
    case "swimming":           return .distanceSwimming
    default:                   return nil
    }
}
#endif

// MARK: - Palette (phone, watch and widgets)
/// The one place the app's colours are defined; the phone's Theme, the watch's T
/// and the widgets read from here.
enum Palette {
    static let bg     = Color(hex: "0b0b0d")
    static let c1     = Color(hex: "141417")
    static let c2     = Color(hex: "1f1f23")
    static let c3     = Color(hex: "2a2a30")
    static let brd2   = Color(hex: "3a3a42")
    static let mut    = Color(hex: "161619")
    static let acc    = Color(hex: "ffe000")
    static let acc2   = Color(hex: "ffb000")
    static let txt    = Color(hex: "f4efe6")
    static let sub    = Color(hex: "9a958d")   // 5.2:1 on the card surface (AA)
    static let red    = Color(hex: "ff5a52")
    static let blue   = Color(hex: "4fb8c4")
    static let good   = Color(hex: "7fc950")
    static let fat    = Color(hex: "ff5da2")
    static let purple = Color(hex: "b08fff")
    static let orange = Color(hex: "ff9500")
}

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
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Type that follows the text-size setting
/// Sizes are written for the default text size and grow with the person's Dynamic
/// Type setting, up to a cap so the dense rows still fit. On the phone no text goes
/// below 12 pt; the watch keeps its own small sizes.
enum TypeScale {
    static let textCap: CGFloat = 1.5
    static let numberCap: CGFloat = 1.3
    static let minPhoneSize: CGFloat = 12

    static func scaled(_ size: CGFloat, cap: CGFloat) -> CGFloat {
        #if os(iOS)
        let base = max(size, minPhoneSize)
        return min(UIFontMetrics.default.scaledValue(for: base), base * cap)
        #else
        return size
        #endif
    }
}

extension Font {
    /// Body and label text.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: TypeScale.scaled(size, cap: TypeScale.textCap), weight: weight)
    }
    /// Heading / label font — used uppercase with tracking.
    static func head(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: TypeScale.scaled(size, cap: TypeScale.textCap), weight: weight)
    }
    /// Numeric font — rounded design for the big stat numbers. Digits are all the
    /// same width, so a ticking timer or a changing value doesn't shift its row.
    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: TypeScale.scaled(size, cap: TypeScale.numberCap), weight: weight, design: .rounded).monospacedDigit()
    }
}
