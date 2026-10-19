import Foundation

// MARK: - Workout file import (FIT / GPX / TCX)
// The universal fallback for any device that does NOT sync to Apple Health
// (Huawei Health, some China-market bands) and for exports from Strava or Garmin
// Connect. FIT is binary; GPX and TCX are XML. Each reader collects the file's own
// totals and its track points; one builder turns both into the session's core
// fields and every extra metric, so the three formats end up alike.

struct TrackPoint {
    var time: Date?
    var lat: Double?
    var lon: Double?
    var ele: Double?
    var hr: Double?
    var cadence: Double?
    var power: Double?
    var speed: Double?        // m/s
    var temp: Double?         // °C
    var distance: Double?     // cumulative metres
}

struct ParsedWorkout {
    var sport: String          // Sport raw value
    var start: Date
    var measures: WorkoutMeasures
    var points: [TrackPoint]

    var date: String { isoFormatter.string(from: start) }
    var durationSec: Int { measures.durationSec }
    var kcal: Int? { measures.kcal }
    var distanceKm: Double? { measures.distanceKm }
    var elevationM: Double? { measures.elevationM }
}

enum WorkoutFile {
    static func parse(_ data: Data) -> ParsedWorkout? {
        FitDecoder.isFit(data) ? FitDecoder.parse(data) : XMLWorkoutParser.parse(data)
    }

    /// What a file states outright (session or lap totals). The track fills the rest.
    struct Totals {
        var start: Date?
        var seconds: Double?
        var metres: Double?
        var kcal: Double?
        var avgHR: Double?
        var maxHR: Double?
        var minHR: Double?
        var ascent: Double?
        var descent: Double?
        var metrics: [WorkoutMetric: Double] = [:]
    }

    /// Climb counted in steps of at least this much, so GPS noise is not summed.
    private static let climbThreshold = 3.0
    /// Below these a running or walking cadence is per leg (strides), as Garmin
    /// files store it, and is doubled to steps per minute.
    private static let strideCadenceBelow: [String: Double] = ["running": 100, "walking": 80]

    static func build(sport: String, totals t: Totals, points: [TrackPoint]) -> ParsedWorkout? {
        let times = points.compactMap(\.time)
        guard let start = t.start ?? times.min() else { return nil }
        let end = times.max() ?? start
        var m = WorkoutMeasures()
        m.durationSec = whole(t.seconds ?? end.timeIntervalSince(start)) ?? 0
        let metres = positive(t.metres ?? points.compactMap(\.distance).max() ?? haversine(points))
        m.distanceKm = metres.map { ($0 / 1000 * 100).rounded() / 100 }
        m.kcal = whole(t.kcal)
        let hrs = points.compactMap(\.hr).filter { $0 > 0 }
        m.avgHR = whole(t.avgHR ?? average(hrs))
        m.maxHR = whole(t.maxHR ?? hrs.max())
        let (gain, loss) = climb(points.compactMap(\.ele))
        m.elevationM = positive(t.ascent ?? gain)

        var x = t.metrics
        func fill(_ k: WorkoutMetric, _ v: Double?) {
            if x[k] == nil, let v, v.isFinite, v > 0 { x[k] = v }
        }
        fill(.minHR, t.minHR ?? hrs.min())
        fill(.elevationLoss, t.descent ?? positive(loss))
        fill(.cadence, average(points.compactMap(\.cadence).filter { $0 > 0 }))
        if let below = strideCadenceBelow[sport], let c = x[.cadence], c < below { x[.cadence] = c * 2 }
        let watts = points.compactMap(\.power)
        fill(.avgPower, average(watts))
        fill(.maxPower, watts.max())
        fill(.maxSpeed, points.compactMap(\.speed).max().map { $0 * 3.6 })
        if x[.temperature] == nil, let temp = average(points.compactMap(\.temp)) { x[.temperature] = temp }
        m.metrics = x
        return ParsedWorkout(sport: sport, start: start, measures: m, points: points)
    }

    /// Files are external data: a value out of any plausible range is dropped,
    /// never converted (Int(1e30) would trap).
    private static let largestValue = 1e9
    static func positive(_ v: Double?) -> Double? { v.flatMap { $0 > 0 && $0 < largestValue ? $0 : nil } }
    static func whole(_ v: Double?) -> Int? { positive(v).map { Int($0.rounded()) } }

    static func climb(_ elevations: [Double]) -> (gain: Double, loss: Double) {
        guard var reference = elevations.first else { return (0, 0) }
        var gain = 0.0, loss = 0.0
        for e in elevations.dropFirst() {
            let d = e - reference
            if d >= climbThreshold { gain += d; reference = e } else if d <= -climbThreshold { loss -= d; reference = e }
        }
        return (gain, loss)
    }

    /// Haversine sum over the points that carry a position (metres).
    static func haversine(_ points: [TrackPoint]) -> Double {
        let pts = points.compactMap { p in p.lat.flatMap { la in p.lon.map { (la, $0) } } }
        guard pts.count > 1 else { return 0 }
        let r = 6_371_000.0
        var total = 0.0
        for i in 1..<pts.count {
            let (la1, lo1) = pts[i - 1], (la2, lo2) = pts[i]
            let dLat = (la2 - la1) * .pi / 180, dLon = (lo2 - lo1) * .pi / 180
            let a = sin(dLat / 2) * sin(dLat / 2) + cos(la1 * .pi / 180) * cos(la2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
            total += r * 2 * atan2(sqrt(a), sqrt(1 - a))
        }
        return total
    }

    /// A free-text sport (TCX Activity@Sport, GPX <type>) as a Sport raw value.
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

// MARK: - GPX / TCX
final class XMLWorkoutParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data) -> ParsedWorkout? {
        let p = XMLWorkoutParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse() else { return nil }
        return p.build()
    }

    private var points: [TrackPoint] = []
    private var point: TrackPoint?
    private var sportRaw: String?
    private var activityID: Date?             // TCX <Id>, the start
    private var lapStarts: [Date] = []
    private var laps = 0
    private var lapSeconds = 0.0, lapMetres = 0.0, lapKcal = 0.0
    private var lapAvgHR: Double?, lapMaxHR: Double?
    private var lapCadence: Double?, lapAvgWatts: Double?, lapMaxWatts: Double?, lapMaxSpeed: Double?

    private var text = ""
    private var hrContext = ""                // which HR block we're inside (TCX)

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoFrac = ISO8601DateFormatter()
    private static func date(_ s: String) -> Date? { iso.date(from: s) ?? isoNoFrac.date(from: s) }

    /// "ns3:hr" -> "hr", "gpxtpx:cad" -> "cad".
    private func local(_ name: String) -> String {
        name.firstIndex(of: ":").map { String(name[name.index(after: $0)...]) } ?? name
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        text = ""
        switch local(elementName) {
        case "Activity":
            if let s = attributeDict["Sport"] { sportRaw = s }
        case "Lap":
            laps += 1
            if let s = attributeDict["StartTime"], let d = Self.date(s) { lapStarts.append(d) }
        case "trkpt":
            point = TrackPoint(lat: attributeDict["lat"].flatMap(Double.init), lon: attributeDict["lon"].flatMap(Double.init))
        case "Trackpoint":
            point = TrackPoint()
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
        text = ""
        let number = Double(value).flatMap { $0.isFinite ? $0 : nil }
        let inPoint = point != nil
        switch name {
        case "trkpt", "Trackpoint":
            if let p = point { points.append(p) }
            point = nil
        case "time", "Time":
            if inPoint { point?.time = Self.date(value) }
        case "Id":
            activityID = Self.date(value)
        case "type":
            if sportRaw == nil, !value.isEmpty { sportRaw = value }
        case "ele", "AltitudeMeters": if inPoint { point?.ele = number }
        case "LatitudeDegrees": point?.lat = number
        case "LongitudeDegrees": point?.lon = number
        case "DistanceMeters":
            // Inside a Trackpoint it is the running total; under a Lap that lap's own.
            if inPoint { point?.distance = number } else if let v = number { lapMetres += v }
        case "Calories": if let v = number { lapKcal += v }
        case "TotalTimeSeconds": if let v = number { lapSeconds += v }
        case "MaximumSpeed": if let v = number { lapMaxSpeed = max(lapMaxSpeed ?? 0, v) }
        case "Value":
            switch hrContext {
            case "avg": lapAvgHR = number
            case "max": if let v = number { lapMaxHR = max(lapMaxHR ?? 0, v) }
            case "tp": point?.hr = number
            default: break
            }
            hrContext = ""
        case "hr": point?.hr = number
        case "cad", "RunCadence": point?.cadence = number
        case "Cadence": if inPoint { point?.cadence = number } else { lapCadence = number }
        case "AvgRunCadence": lapCadence = number
        case "Watts", "power", "PowerInWatts": point?.power = number
        case "AvgWatts": lapAvgWatts = number
        case "MaxWatts": if let v = number { lapMaxWatts = max(lapMaxWatts ?? 0, v) }
        case "Speed", "speed": if inPoint { point?.speed = number }
        case "atemp", "temp": point?.temp = number
        case "AverageHeartRateBpm", "MaximumHeartRateBpm", "HeartRateBpm": hrContext = ""
        default: break
        }
    }

    private func build() -> ParsedWorkout? {
        var t = WorkoutFile.Totals()
        t.start = points.compactMap(\.time).min() ?? lapStarts.min() ?? activityID
        t.seconds = lapSeconds > 0 ? lapSeconds : nil
        t.metres = lapMetres > 0 ? lapMetres : nil
        t.kcal = lapKcal > 0 ? lapKcal : nil
        t.maxHR = lapMaxHR
        // A lap's own average speaks for the workout only when it is the only lap.
        if laps == 1 {
            t.avgHR = lapAvgHR
            t.metrics[.cadence] = lapCadence
            t.metrics[.avgPower] = lapAvgWatts
        }
        if laps > 1 { t.metrics[.laps] = Double(laps) }
        t.metrics[.maxPower] = lapMaxWatts
        t.metrics[.maxSpeed] = lapMaxSpeed.map { $0 * 3.6 }
        t.metrics = t.metrics.filter { $0.value > 0 }
        return WorkoutFile.build(sport: WorkoutFile.mapSport(sportRaw), totals: t, points: points)
    }
}

// MARK: - FIT (Garmin's binary format)
// Records are definition messages (the layout of a local message type) and data
// messages laid out by them. Only three messages matter here: session (18) for
// the totals, lap (19) to count laps and record (20) for the track.
enum FitDecoder {
    private static let epochOffset: TimeInterval = 631_065_600     // 1989-12-31 UTC
    private static let semicircles = 180.0 / 2_147_483_648.0

    private struct Definition {
        let global: Int
        let bigEndian: Bool
        let fields: [(number: Int, size: Int, base: UInt8)]
        let developerBytes: Int
    }

    static func isFit(_ data: Data) -> Bool {
        data.count >= 12 && data.subdata(in: data.startIndex + 8..<data.startIndex + 12) == Data(".FIT".utf8)
    }

    static func parse(_ data: Data) -> ParsedWorkout? {
        let b = [UInt8](data)
        let headerSize = Int(b[0])
        guard headerSize >= 12, b.count >= headerSize else { return nil }
        let dataSize = Int(b[4]) | Int(b[5]) << 8 | Int(b[6]) << 16 | Int(b[7]) << 24
        let end = min(b.count, headerSize + dataSize)
        var i = headerSize
        var definitions: [Int: Definition] = [:]
        var lastTimestamp: UInt32 = 0
        var session: [Int: Double]?
        var laps = 0
        var points: [TrackPoint] = []

        while i < end {
            let header = b[i]
            i += 1
            if header & 0x40 != 0, header & 0x80 == 0 {
                // Definition message.
                guard i + 5 <= end else { break }
                let big = b[i + 1] == 1
                let global = big ? Int(b[i + 2]) << 8 | Int(b[i + 3]) : Int(b[i + 2]) | Int(b[i + 3]) << 8
                let count = Int(b[i + 4])
                i += 5
                guard i + count * 3 <= end else { break }
                let fields = (0..<count).map { k in (Int(b[i + k * 3]), Int(b[i + k * 3 + 1]), b[i + k * 3 + 2]) }
                i += count * 3
                var developerBytes = 0
                if header & 0x20 != 0 {
                    guard i < end else { break }
                    let devCount = Int(b[i])
                    i += 1
                    guard i + devCount * 3 <= end else { break }
                    developerBytes = (0..<devCount).reduce(0) { $0 + Int(b[i + $1 * 3 + 1]) }
                    i += devCount * 3
                }
                definitions[Int(header & 0x0F)] = Definition(global: global, bigEndian: big, fields: fields, developerBytes: developerBytes)
                continue
            }
            // Data message, normal or with a compressed timestamp.
            let compressed = header & 0x80 != 0
            let local = compressed ? Int((header >> 5) & 0x03) : Int(header & 0x0F)
            guard let def = definitions[local] else { return nil }
            let size = def.fields.reduce(0) { $0 + $1.size } + def.developerBytes
            guard i + size <= end else { break }
            var values: [Int: Double] = [:]
            var at = i
            for f in def.fields {
                if let v = number(b[at..<at + f.size], base: f.base, bigEndian: def.bigEndian) { values[f.number] = v }
                at += f.size
            }
            i += size
            if compressed {
                let offset = UInt32(header & 0x1F)
                // Wrapping arithmetic: a corrupt file near the top of the range
                // must not trap.
                var ts = (lastTimestamp & ~0x1F) &+ offset
                if offset < lastTimestamp & 0x1F { ts &+= 0x20 }
                lastTimestamp = ts
                values[253] = Double(ts)
            } else if let ts = values[253] {
                guard let valid = UInt32(exactly: ts) else { return nil }
                lastTimestamp = valid
            }
            switch def.global {
            case 18: if session == nil { session = values }
            case 19: laps += 1
            case 20: points.append(point(values))
            default: break
            }
        }
        return build(session: session ?? [:], laps: laps, points: points)
    }

    private static func date(_ fit: Double) -> Date { Date(timeIntervalSince1970: fit + epochOffset) }

    private static func point(_ v: [Int: Double]) -> TrackPoint {
        var p = TrackPoint()
        p.time = v[253].map(date)
        p.lat = v[0].map { $0 * semicircles }
        p.lon = v[1].map { $0 * semicircles }
        p.ele = (v[78] ?? v[2]).map { $0 / 5 - 500 }
        p.hr = v[3]
        p.cadence = v[4]
        p.distance = v[5].map { $0 / 100 }
        p.speed = (v[73] ?? v[6]).map { $0 / 1000 }
        p.power = v[7]
        p.temp = v[13]
        return p
    }

    private static func build(session s: [Int: Double], laps: Int, points: [TrackPoint]) -> ParsedWorkout? {
        var t = WorkoutFile.Totals()
        t.start = s[2].map(date)
        t.seconds = (s[8] ?? s[7]).map { $0 / 1000 }
        t.metres = s[9].map { $0 / 100 }
        t.kcal = s[11]
        t.avgHR = s[16]
        t.maxHR = s[17]
        t.minHR = s[64]
        t.ascent = s[22]
        t.descent = s[23]
        let sport = sportName(s[5].map(Int.init), sub: s[6].map(Int.init))
        var m: [WorkoutMetric: Double] = [:]
        m[.avgSpeed] = (s[124] ?? s[14]).map { $0 / 1000 * 3.6 }
        m[.maxSpeed] = (s[125] ?? s[15]).map { $0 / 1000 * 3.6 }
        m[.cadence] = s[18]
        m[.avgPower] = s[20]
        m[.maxPower] = s[21]
        m[.aerobicEffect] = s[24].map { $0 / 10 }
        m[.anaerobicEffect] = s[137].map { $0 / 10 }
        m[.laps] = s[26] ?? (laps > 1 ? Double(laps) : nil)
        m[.poolLength] = s[44].map { $0 / 100 }
        m[.verticalOsc] = s[89].map { $0 / 100 }          // 0.1 mm -> cm
        m[.groundContact] = s[91].map { $0 / 10 }          // 0.1 ms -> ms
        if sport == "swimming" { m[.strokes] = s[10] }
        if let temp = s[57] { t.metrics[.temperature] = temp }
        t.metrics.merge(m.filter { $0.value > 0 }) { a, _ in a }
        return WorkoutFile.build(sport: sport, totals: t, points: points)
    }

    /// FIT sport and sub-sport codes.
    private static func sportName(_ sport: Int?, sub: Int?) -> String {
        if sub == 20 { return "strength" }               // strength_training
        switch sport {
        case 1: return "running"
        case 2: return "cycling"
        case 5: return "swimming"
        case 11, 17: return "walking"                     // walking, hiking
        default: return "other"
        }
    }

    /// One field's value, or nil when it holds the base type's "invalid" marker
    /// or is an array or string.
    private static func number(_ bytes: ArraySlice<UInt8>, base: UInt8, bigEndian: Bool) -> Double? {
        let ordered = bigEndian ? Array(bytes.reversed()) : Array(bytes)
        let raw = ordered.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << UInt64(8 * $1.offset) }
        switch (base & 0x1F, bytes.count) {
        case (0, 1), (2, 1): return raw == 0xFF ? nil : Double(raw)
        case (10, 1): return raw == 0 ? nil : Double(raw)
        case (1, 1): return raw == 0x7F ? nil : Double(Int8(bitPattern: UInt8(raw)))
        case (3, 2): return raw == 0x7FFF ? nil : Double(Int16(bitPattern: UInt16(raw)))
        case (4, 2): return raw == 0xFFFF ? nil : Double(raw)
        case (11, 2): return raw == 0 ? nil : Double(raw)
        case (5, 4): return raw == 0x7FFF_FFFF ? nil : Double(Int32(bitPattern: UInt32(raw)))
        case (6, 4): return raw == 0xFFFF_FFFF ? nil : Double(raw)
        case (12, 4): return raw == 0 ? nil : Double(raw)
        case (8, 4):
            let v = Double(Float(bitPattern: UInt32(raw)))
            return raw == 0xFFFF_FFFF || !v.isFinite ? nil : v
        case (9, 8):
            let v = Double(bitPattern: raw)
            return v.isFinite ? v : nil
        default: return nil
        }
    }
}
