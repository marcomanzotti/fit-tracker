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

private var formatterCache: [String: DateFormatter] = [:]
/// A formatter for a fixed format and locale, created once. Building a
/// DateFormatter is slow, and chart axes and day headers ask for one per label.
/// Main thread only (it is used from views and the derived-data helpers).
func cachedFormatter(_ format: String, locale: String = "en_US_POSIX") -> DateFormatter {
    let key = locale + "|" + format
    if let cached = formatterCache[key] { return cached }
    let f = DateFormatter()
    f.locale = Locale(identifier: locale)
    f.dateFormat = format
    formatterCache[key] = f
    return f
}

/// "Martedì 13 Ottobre" for a yyyy-MM-dd key, in the app's language.
func prettyDay(_ date: String) -> String {
    guard let d = isoFormatter.date(from: date) else { return date }
    return cachedFormatter("EEEE d MMMM", locale: L.lang == "en" ? "en_US" : "it_IT").string(from: d).capitalized
}

/// The time window of a chart that would otherwise plot its whole history.
enum ChartWindow: String, CaseIterable, Identifiable {
    case m1, m3, m6, y1, all
    var id: String { rawValue }
    var label: String { t("chart.win." + rawValue) }
    private var months: Int? {
        switch self {
        case .m1: return 1
        case .m3: return 3
        case .m6: return 6
        case .y1: return 12
        case .all: return nil
        }
    }
    /// Whether a yyyy-MM-dd date falls inside the window.
    func contains(_ date: String) -> Bool {
        guard let months, let from = Calendar.current.date(byAdding: .month, value: -months, to: Date()) else { return true }
        return date >= isoFormatter.string(from: from)
    }
}

/// A yyyy-MM-dd date as a Date for a chart axis (start of that day).
func chartDay(_ date: String) -> Date { isoFormatter.date(from: date) ?? Date() }

/// An axis label sized to the span shown: days for about two months, months up to
/// a year, month and year beyond — always a handful of short labels.
func axisDate(_ d: Date, spanDays: Double) -> String {
    let format = spanDays <= 70 ? "d MMM" : (spanDays <= 400 ? "MMM" : "MMM yy")
    return cachedFormatter(format, locale: L.lang == "en" ? "en_US" : "it_IT").string(from: d)
}

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

/// Monday 00:00 of the week `offset` weeks before the one containing `now`. Weeks
/// in this app always run Monday to Sunday, whatever the device's first weekday.
func weekStart(offset: Int = 0, now: Date = Date(), calendar: Calendar = .current) -> Date {
    let daysSinceMonday = (calendar.component(.weekday, from: now) + 5) % 7
    let today = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: -daysSinceMonday - offset * 7, to: today) ?? today
}

/// Total seconds -> compact "1h 05m", "45m 30s" or "30s" for session summaries.
func fmtDuration(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    if h > 0 { return String(format: "%dh %02dm", h, m) }
    if m > 0 { return s > 0 ? String(format: "%dm %02ds", m, s) : "\(m)m" }
    return "\(s)s"
}

/// Seconds as a running clock: "4:05", or "1:04:05" past the hour.
func fmtClock(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Number formatting
func trimNum(_ v: Double) -> String {
    guard v.isFinite else { return "—" }
    // Int(v) traps outside Int's range, so only whole numbers well inside it.
    if v == v.rounded(), abs(v) < 1e15 { return String(Int(v)) }
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
// Generators are created once and re-armed after each use: a fresh generator per
// tap has to spin the Taptic Engine up first, so the tick lands late.
private let notifier = UINotificationFeedbackGenerator()
private let lightImpact = UIImpactFeedbackGenerator(style: .light)

func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    notifier.notificationOccurred(type)
    notifier.prepare()
}
func tap() {
    lightImpact.impactOccurred()
    lightImpact.prepare()
}

/// A celebratory burst when a set crosses into personal-record territory: a
/// success notification followed by a quick light tap so it feels distinct from
/// the rest-timer alert.
func prHaptic() {
    let notif = UINotificationFeedbackGenerator()
    notif.notificationOccurred(.success)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
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


// MARK: - Collection helpers
extension Array where Element: Hashable {
    /// Duplicate-free copy that keeps the original order (Set loses it).
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Text helpers
/// Capitalise the first letter of every word; rest lowercase.
func titleCased(_ s: String) -> String {
    s.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
        guard let first = word.first else { return String(word) }
        return first.uppercased() + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
