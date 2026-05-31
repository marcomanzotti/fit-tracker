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

func headerDate() -> (full: String, day: String) {
    let cal = Calendar.current
    let now = Date()
    let d = cal.component(.day, from: now)
    let m = cal.component(.month, from: now) - 1
    let y = cal.component(.year, from: now)
    let wd = cal.component(.weekday, from: now) - 1
    return ("\(d) \(L.months[max(0, min(11, m))]) \(y)", L.days[max(0, min(6, wd))])
}

// MARK: - Number formatting
func trimNum(_ v: Double) -> String {
    if v == v.rounded() { return String(Int(v)) }
    return String(format: "%g", v)
}

// MARK: - Haptics
func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    let g = UINotificationFeedbackGenerator()
    g.notificationOccurred(type)
}
func tap() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
