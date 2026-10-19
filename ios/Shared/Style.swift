import SwiftUI

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

extension Font {
    /// Heading / label font — used uppercase with tracking.
    static func head(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    /// Numeric font — rounded design for the big stat numbers. Digits are all the
    /// same width, so a ticking timer or a changing value doesn't shift its row.
    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
