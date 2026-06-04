import SwiftUI
import UIKit

// MARK: - Dates
let isoFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func today() -> String { isoFormatter.string(from: Date()) }

/// "2024-05-31" -> "05-31"   (mirrors the web app's fmt())
func fmtShort(_ date: String) -> String { String(date.dropFirst(5)) }

/// "2024-05-31" -> "31/05"   (short, readable day/month for dense charts)
func fmtDM(_ date: String) -> String {
    let p = date.split(separator: "-")
    guard p.count == 3 else { return date }
    return "\(p[2])/\(p[1])"
}

func headerDate() -> (full: String, day: String) {
    let cal = Calendar.current
    let now = Date()
    let d = cal.component(.day, from: now)
    let m = cal.component(.month, from: now) - 1
    let y = cal.component(.year, from: now)
    let wd = cal.component(.weekday, from: now) - 1
    return ("\(d) \(L.months[max(0, min(11, m))]) \(y)", L.days[max(0, min(6, wd))])
}

/// Total seconds -> compact "1h 05m", "45m 30s" or "30s" for session summaries.
func fmtDuration(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    if h > 0 { return String(format: "%dh %02dm", h, m) }
    if m > 0 { return s > 0 ? String(format: "%dm %02ds", m, s) : "\(m)m" }
    return "\(s)s"
}

// MARK: - Number formatting
func trimNum(_ v: Double) -> String {
    if v == v.rounded() { return String(Int(v)) }
    return String(format: "%g", v)
}

// MARK: - Units (metric / imperial)
// All values are STORED in metric (kg, cm, km, height in metres). The user can
// switch the displayed unit system at any time; like L.lang, `Units.imperial`
// is kept in sync with prefs by the Store, so flipping it re-renders every
// converted value. Conversions happen only at the display/input boundary.
enum Units {
    static var imperial = false

    static var wLabel: String { imperial ? "lb" : "kg" }       // body / lift weight
    static var lenLabel: String { imperial ? "in" : "cm" }     // circumferences
    static var distLabel: String { imperial ? "mi" : "km" }    // cardio distance
    static var heightLabel: String { imperial ? "in" : "cm" }

    // kg <-> display
    static func wOut(_ kg: Double) -> Double { imperial ? kg * 2.2046226 : kg }
    static func wIn(_ v: Double) -> Double { imperial ? v / 2.2046226 : v }
    // cm <-> display
    static func lenOut(_ cm: Double) -> Double { imperial ? cm * 0.3937008 : cm }
    static func lenIn(_ v: Double) -> Double { imperial ? v / 0.3937008 : v }
    // km <-> display
    static func distOut(_ km: Double) -> Double { imperial ? km * 0.6213712 : km }
    static func distIn(_ v: Double) -> Double { imperial ? v / 0.6213712 : v }
    // metres (height) <-> display (cm or inches)
    static func heightOut(_ m: Double) -> Double { imperial ? m * 39.37008 : m * 100 }
    static func heightIn(_ v: Double) -> Double { imperial ? v / 39.37008 : v / 100 }
}

/// Convenience: a stored kg value formatted in the user's weight unit (no label).
func dispW(_ kg: Double) -> String { trimNum((Units.wOut(kg) * 10).rounded() / 10) }
/// A stored cm value formatted in the user's length unit (no label).
func dispLen(_ cm: Double) -> String { trimNum((Units.lenOut(cm) * 10).rounded() / 10) }
/// A stored km value formatted in the user's distance unit (no label).
func dispDist(_ km: Double) -> String { trimNum((Units.distOut(km) * 100).rounded() / 100) }

// MARK: - Haptics
func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    let g = UINotificationFeedbackGenerator()
    g.notificationOccurred(type)
}
func tap() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

/// A stronger, unmistakable alert when the rest timer finishes — a success
/// notification plus two heavy impacts spaced out, so it's felt even mid-set.
func restDoneHaptic() {
    let notif = UINotificationFeedbackGenerator()
    notif.notificationOccurred(.success)
    let heavy = UIImpactFeedbackGenerator(style: .heavy)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { heavy.impactOccurred() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { heavy.impactOccurred() }
}


// MARK: - Text helpers
/// Capitalise the first letter of every word; rest lowercase.
func titleCased(_ s: String) -> String {
    s.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
        guard let first = word.first else { return String(word) }
        return first.uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
