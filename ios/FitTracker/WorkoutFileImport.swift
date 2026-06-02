import Foundation

// MARK: - GPX / TCX workout file import
// The universal fallback for any sensor that does NOT sync to Apple Health
// (Huawei Health, some China-market bands, or any app that only lets you export
// a file). GPX and TCX are both XML; this one XMLParser-based reader handles both
// and reduces a track to the same fields the app stores in a WorkoutSession:
// sport, start date, duration, distance, calories and average/max heart rate.

struct ParsedWorkout {
    var sport: String          // Sport raw value
    var date: String           // yyyy-MM-dd of the start
    var durationSec: Int
    var distanceKm: Double?
    var kcal: Int?
    var avgHR: Int?
    var maxHR: Int?
}

final class WorkoutFileParser: NSObject, XMLParserDelegate {
    static func parse(data: Data) -> ParsedWorkout? {
        let p = WorkoutFileParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse() else { return nil }
        return p.build()
    }

    // Accumulators (shared by both formats)
    private var times: [Date] = []          // every <time>/<Time> seen
    private var hrs: [Int] = []             // per-trackpoint heart rates
    private var coords: [(Double, Double)] = []  // lat/lon for distance fallback
    private var sportRaw: String?           // TCX Activity@Sport / GPX <type>
    private var lapDistance: Double = 0      // summed TCX Lap DistanceMeters (m)
    private var lapCalories: Int = 0         // summed TCX Lap Calories
    private var lapSeconds: Double = 0       // summed TCX Lap TotalTimeSeconds
    private var explicitAvg: Int?            // TCX AverageHeartRateBpm
    private var explicitMax: Int?            // TCX MaximumHeartRateBpm

    // Parse cursor
    private var text = ""                    // characters of the current element
    private var hrContext = ""               // which HR block we're inside (TCX)

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private func parseDate(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return iso.date(from: t) ?? isoNoFrac.date(from: t)
    }

    // Strip a namespace prefix ("ns3:hr" -> "hr", "gpxtpx:hr" -> "hr").
    private func local(_ name: String) -> String {
        if let i = name.firstIndex(of: ":") { return String(name[name.index(after: i)...]) }
        return name
    }

    // MARK: XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let name = local(elementName)
        text = ""
        switch name {
        case "Activity":                       // TCX
            if let s = attributeDict["Sport"] { sportRaw = s }
        case "trkpt", "Trackpoint":            // GPX trackpoint carries lat/lon as attrs
            if let la = attributeDict["lat"], let lo = attributeDict["lon"],
               let lat = Double(la), let lon = Double(lo) { coords.append((lat, lon)) }
        case "AverageHeartRateBpm": hrContext = "avg"
        case "MaximumHeartRateBpm": hrContext = "max"
        case "HeartRateBpm":        hrContext = "tp"
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = local(elementName)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "time", "Time", "Id":
            if let d = parseDate(value) { times.append(d) }
        case "type":                            // GPX <trk><type>running</type>
            if sportRaw == nil, !value.isEmpty { sportRaw = value }
        case "ele", "AltitudeMeters":
            break                               // captured but unused for now
        case "DistanceMeters":
            // TCX: Lap-level cumulative distance. Keep the max we ever see (the
            // last lap's running total is the full distance).
            if let v = Double(value) { lapDistance = max(lapDistance, v) }
        case "Calories":
            if let v = Int(value) { lapCalories += v }
        case "TotalTimeSeconds":
            if let v = Double(value) { lapSeconds += v }
        case "Value":                           // TCX HR value, meaning set by context
            if let v = Int(value) {
                switch hrContext {
                case "avg": explicitAvg = v
                case "max": explicitMax = v
                case "tp":  hrs.append(v)
                default: break
                }
            }
            hrContext = ""
        case "hr":                              // GPX extension <gpxtpx:hr> / <ns3:hr>
            if let v = Int(value) { hrs.append(v) }
        case "AverageHeartRateBpm", "MaximumHeartRateBpm", "HeartRateBpm":
            hrContext = ""
        default: break
        }
        text = ""
    }

    // MARK: Build the result
    private func build() -> ParsedWorkout? {
        guard let start = times.min() else { return nil }
        let end = times.max() ?? start
        var dur = Int(lapSeconds.rounded())
        if dur <= 0 { dur = Int(end.timeIntervalSince(start).rounded()) }

        var km: Double? = nil
        if lapDistance > 0 { km = (lapDistance / 1000 * 100).rounded() / 100 }
        else if coords.count > 1 {
            let m = WorkoutFileParser.distance(coords)
            if m > 0 { km = (m / 1000 * 100).rounded() / 100 }
        }

        let avg = explicitAvg ?? (hrs.isEmpty ? nil : Int((Double(hrs.reduce(0, +)) / Double(hrs.count)).rounded()))
        let mx  = explicitMax ?? hrs.max()

        return ParsedWorkout(
            sport: WorkoutFileParser.mapSport(sportRaw),
            date: dateKey(start),
            durationSec: max(0, dur),
            distanceKm: km,
            kcal: lapCalories > 0 ? lapCalories : nil,
            avgHR: avg, maxHR: mx)
    }

    // yyyy-MM-dd in the local calendar (matches the app's day keys).
    private func dateKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    // Haversine sum over a coordinate list (meters).
    static func distance(_ pts: [(Double, Double)]) -> Double {
        guard pts.count > 1 else { return 0 }
        let R = 6_371_000.0
        var total = 0.0
        for i in 1..<pts.count {
            let (la1, lo1) = pts[i - 1]
            let (la2, lo2) = pts[i]
            let dLat = (la2 - la1) * .pi / 180
            let dLon = (lo2 - lo1) * .pi / 180
            let a = sin(dLat / 2) * sin(dLat / 2)
                  + cos(la1 * .pi / 180) * cos(la2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
            total += R * 2 * atan2(sqrt(a), sqrt(1 - a))
        }
        return total
    }

    // Map a free-text sport string (TCX Sport attr / GPX type) to a Sport raw value.
    static func mapSport(_ s: String?) -> String {
        guard let s = s?.lowercased() else { return "other" }
        if s.contains("run") { return "running" }
        if s.contains("bik") || s.contains("cycl") { return "cycling" }
        if s.contains("walk") || s.contains("hik") { return "walking" }
        if s.contains("swim") { return "swimming" }
        if s.contains("strength") || s.contains("weight") { return "strength" }
        return "other"
    }
}
