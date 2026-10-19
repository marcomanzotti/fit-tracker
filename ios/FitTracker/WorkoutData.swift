import Foundation
#if canImport(HealthKit)
import CoreLocation
import HealthKit
#endif

// MARK: - Workout metrics beyond the core fields
// Duration, distance, calories, average/max heart rate and climb have their own
// fields on WorkoutSession. Everything else a wearable can report lives here, one
// canonical unit per metric, so a value reads the same whichever device measured
// it. The device's value and the user's typed value are kept apart: the typed one
// wins, and a sync only ever rewrites the device's.

enum WorkoutMetric: String, CaseIterable, Identifiable {
    case minHR, steps, cadence, strideLength, avgSpeed, maxSpeed, elevationLoss
    case avgPower, maxPower, groundContact, verticalOsc
    case strokes, laps, poolLength, swolf, jumps
    case mets, temperature, humidity
    case aerobicEffect, anaerobicEffect, trainingLoad, recoveryHours, vo2max

    var id: String { rawValue }
    var labelKey: String { "wm." + rawValue }

    var unit: String {
        switch self {
        case .minHR: return "bpm"
        case .cadence: return "/min"
        case .strideLength, .poolLength, .elevationLoss: return "m"
        case .avgSpeed, .maxSpeed: return "km/h"
        case .avgPower, .maxPower: return "W"
        case .groundContact: return "ms"
        case .verticalOsc: return "cm"
        case .mets: return "MET"
        case .temperature: return "°C"
        case .humidity: return "%"
        case .recoveryHours: return "h"
        case .vo2max: return "ml/kg/min"
        case .steps, .strokes, .laps, .swolf, .jumps, .aerobicEffect, .anaerobicEffect, .trainingLoad: return ""
        }
    }

    private var decimals: Int {
        switch self {
        case .strideLength: return 2
        case .avgSpeed, .maxSpeed, .verticalOsc, .mets, .temperature, .aerobicEffect, .anaerobicEffect, .vo2max: return 1
        default: return 0
        }
    }

    func format(_ v: Double) -> String {
        let scale = pow(10, Double(decimals))
        return trimNum((v * scale).rounded() / scale)
    }

    /// A brand's own score, computed its own way: shown for what it is, never
    /// compared across devices (the app's TRIMP and zones do that job).
    var isDeviceScore: Bool {
        switch self {
        case .aerobicEffect, .anaerobicEffect, .trainingLoad, .recoveryHours, .vo2max: return true
        default: return false
        }
    }
}

extension WorkoutSession {
    /// The value in use: typed by the user, else measured by the device.
    func metric(_ m: WorkoutMetric) -> Double? { metricOverrides?[m.rawValue] ?? metrics?[m.rawValue] }
    func deviceMetric(_ m: WorkoutMetric) -> Double? { metrics?[m.rawValue] }
    var shownMetrics: [WorkoutMetric] { WorkoutMetric.allCases.filter { metric($0) != nil } }

    /// Type a value, or pass nil to go back to the device's.
    mutating func setTyped(_ m: WorkoutMetric, _ value: Double?) {
        var typed = metricOverrides ?? [:]
        typed[m.rawValue] = value
        metricOverrides = typed.isEmpty ? nil : typed
    }

    /// Take what a device reported: its new values replace its old ones, values it
    /// no longer reports are kept, typed values are never touched.
    mutating func absorbDevice(_ values: [WorkoutMetric: Double]) {
        guard !values.isEmpty else { return }
        var merged = metrics ?? [:]
        for (m, v) in values where v.isFinite { merged[m.rawValue] = v }
        metrics = merged
    }

    /// Fill the core fields the session does not have yet, then take the extra
    /// metrics. What is there, typed or measured before, stays. A second device's
    /// record of the same workout (`onlyMissingMetrics`) adds only metrics the
    /// first did not measure.
    mutating func absorb(_ m: WorkoutMeasures, onlyMissingMetrics: Bool = false) {
        if durationSeconds == nil, m.durationSec > 0 { durationSec = m.durationSec }
        if caloriesManual == nil, let k = m.kcal, k > 0 { caloriesManual = k }
        if (distanceKm ?? 0) <= 0, let km = m.distanceKm, km > 0 { distanceKm = km }
        if avgHR == nil, let hr = m.avgHR, hr > 0 { avgHR = hr }
        if maxHRSes == nil, let hr = m.maxHR, hr > 0 { maxHRSes = hr }
        if elevationM == nil, let e = m.elevationM, e > 0 { elevationM = e }
        absorbDevice(onlyMissingMetrics ? m.metrics.filter { metrics?[$0.key.rawValue] == nil } : m.metrics)
    }

    /// This session and a Health workout are the same workout.
    mutating func link(_ w: HealthWorkout) {
        healthUUID = w.uuid
        takeTimes(of: w)
        absorb(w.measures)
    }

    /// The workout's time span, when the session has none yet.
    mutating func takeTimes(of w: HealthWorkout) {
        guard startTime == nil || endTime == nil, let start = w.start, let end = w.end else { return }
        startTime = start
        endTime = end
    }
}

// MARK: - What a Health workout holds
/// The core values plus every extra metric read from one HKWorkout.
struct WorkoutMeasures {
    var durationSec = 0
    var kcal: Int?
    var distanceKm: Double?
    var avgHR: Int?
    var maxHR: Int?
    var elevationM: Double?
    var metrics: [WorkoutMetric: Double] = [:]
}

/// Seconds spent in each of five zones (`bounds`: six edges in bpm). Each reading
/// stands for the time until the next one, capped so a dropout is not credited to
/// the last zone seen.
func hrZoneSeconds(_ hr: [(Date, Double)], end: Date, bounds: [Int], longestGap: TimeInterval = 120) -> [Double] {
    var zones = [Double](repeating: 0, count: 5)
    for (i, s) in hr.enumerated() {
        let next = i + 1 < hr.count ? hr[i + 1].0 : end
        let seconds = min(next.timeIntervalSince(s.0), longestGap)
        let zone = max(0, min(4, bounds.lastIndex { Double($0) <= s.1 } ?? 0))
        zones[zone] += max(0, seconds)
    }
    return zones
}

// MARK: - Series, read when a workout is opened
struct SeriesPoint: Identifiable {
    let time: Date
    let value: Double
    var id: Date { time }
}

struct WorkoutSplit: Identifiable {
    let index: Int          // 1-based kilometre
    let seconds: Double
    let avgHR: Double?
    var id: Int { index }
}

struct WorkoutSeries {
    var start: Date
    var end: Date
    var heartRate: [SeriesPoint] = []
    var route: [(lat: Double, lon: Double)] = []
    var splits: [WorkoutSplit] = []

    var isEmpty: Bool { heartRate.isEmpty && route.isEmpty && splits.isEmpty }
}

#if canImport(HealthKit)
extension HealthKitManager {
    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let metresPerSecond = HKUnit.meter().unitDivided(by: .second())
    private static let metUnit = HKUnit.kilocalorie().unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))
    private static let kmhPerMetrePerSecond = 3.6
    private static let bandPrefix = "band10."
    private static let chartPoints = 300
    private static let metresPerSplit = 1000.0

    /// Extra types a workout can carry, read on top of the daily ones.
    static var workoutReadTypes: [HKObjectType] {
        let ids: [HKQuantityTypeIdentifier] = [.heartRate, .stepCount, .runningPower, .runningSpeed, .runningStrideLength,
                                               .runningGroundContactTime, .runningVerticalOscillation, .swimmingStrokeCount,
                                               .cyclingPower, .cyclingCadence, .cyclingSpeed, .physicalEffort]
        return ids.compactMap { HKObjectType.quantityType(forIdentifier: $0) } + [HKSeriesType.workoutRoute()]
    }

    /// Everything one workout tells: its statistics, its metadata (standard keys
    /// and the band's own), its lap events. No extra query, so a sync can read a
    /// whole season of workouts.
    static func measures(of w: HKWorkout) -> WorkoutMeasures {
        // Bounded too: a corrupt value would trap in the Int conversions below.
        func positive(_ v: Double?) -> Double? { v.flatMap { $0.isFinite && $0 > 0 && $0 < 1e9 ? $0 : nil } }
        func stat(_ id: HKQuantityTypeIdentifier) -> HKStatistics? {
            HKObjectType.quantityType(forIdentifier: id).flatMap { w.statistics(for: $0) }
        }
        func avg(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? { positive(stat(id)?.averageQuantity()?.doubleValue(for: unit)) }
        func most(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? { positive(stat(id)?.maximumQuantity()?.doubleValue(for: unit)) }
        func least(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? { positive(stat(id)?.minimumQuantity()?.doubleValue(for: unit)) }
        func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? { positive(stat(id)?.sumQuantity()?.doubleValue(for: unit)) }
        let meta = w.metadata ?? [:]
        func band(_ name: String) -> Double? { positive((meta[bandPrefix + name] as? NSNumber)?.doubleValue) }
        func quantity(_ key: String, _ unit: HKUnit) -> Double? {
            guard let q = meta[key] as? HKQuantity, q.is(compatibleWith: unit) else { return nil }
            return positive(q.doubleValue(for: unit))
        }

        var out = WorkoutMeasures()
        let seconds = band("activeSeconds") ?? w.duration
        out.durationSec = Int(seconds.rounded())
        out.avgHR = (avg(.heartRate, bpm) ?? band("averageHeartRate")).map { Int($0.rounded()) }
        out.maxHR = (most(.heartRate, bpm) ?? band("maximumHeartRate")).map { Int($0.rounded()) }
        out.kcal = (sum(.activeEnergyBurned, .kilocalorie()) ?? band("activeCalories")).map { Int($0.rounded()) }
        let metres = positive(w.totalDistance?.doubleValue(for: .meter()))
            ?? sum(.distanceWalkingRunning, .meter()) ?? sum(.distanceCycling, .meter()) ?? sum(.distanceSwimming, .meter())
            ?? band("distance")
        out.distanceKm = metres.map { ($0 / 1000 * 100).rounded() / 100 }
        out.elevationM = quantity(HKMetadataKeyElevationAscended, .meter()) ?? band("elevationGain")

        var m: [WorkoutMetric: Double] = [:]
        func put(_ metric: WorkoutMetric, _ candidates: Double?...) {
            if let v = candidates.compactMap({ $0 }).first { m[metric] = v }
        }
        let steps = sum(.stepCount, .count()) ?? band("steps")
        put(.minHR, least(.heartRate, bpm), band("minimumHeartRate"))
        put(.steps, steps)
        let cyclingCadence = avg(.cyclingCadence, bpm)
        let cyclingPower = avg(.cyclingPower, .watt())
        let cyclingMaxPower = most(.cyclingPower, .watt())
        let cyclingSpeed = avg(.cyclingSpeed, metresPerSecond)
        let cyclingMaxSpeed = most(.cyclingSpeed, metresPerSecond)
        let effort = avg(.physicalEffort, metUnit)
        let onFoot: Set<HKWorkoutActivityType> = [.running, .walking, .hiking]
        let stepCadence = steps.flatMap { s in seconds > 0 && onFoot.contains(w.workoutActivityType) ? s / (seconds / 60) : nil }
        put(.cadence, cyclingCadence, band("averageCadence"), stepCadence)
        put(.strideLength, avg(.runningStrideLength, .meter()), band("strideLength"))
        let kmh = { (v: Double?) in v.map { $0 * kmhPerMetrePerSecond } }
        put(.avgSpeed, kmh(avg(.runningSpeed, metresPerSecond)), kmh(cyclingSpeed),
            kmh(quantity(HKMetadataKeyAverageSpeed, metresPerSecond)), band("averageSpeed"))
        put(.maxSpeed, kmh(most(.runningSpeed, metresPerSecond)), kmh(cyclingMaxSpeed),
            kmh(quantity(HKMetadataKeyMaximumSpeed, metresPerSecond)), band("maximumSpeed"))
        put(.elevationLoss, band("elevationLoss"))
        put(.avgPower, avg(.runningPower, .watt()), cyclingPower)
        put(.maxPower, most(.runningPower, .watt()), cyclingMaxPower)
        put(.groundContact, avg(.runningGroundContactTime, .secondUnit(with: .milli)), band("groundContactTime"))
        put(.verticalOsc, avg(.runningVerticalOscillation, .meterUnit(with: .centi)), band("verticalOscillation"))
        put(.strokes, sum(.swimmingStrokeCount, .count()), band("strokes"))
        let lapEvents = Double(w.workoutEvents?.filter { $0.type == .lap }.count ?? 0)
        put(.laps, positive(lapEvents), band("laps"))
        put(.poolLength, quantity(HKMetadataKeyLapLength, .meter()), band("poolLength"))
        put(.swolf, band("swolf"))
        put(.jumps, band("jumps"))
        put(.mets, quantity(HKMetadataKeyAverageMETs, metUnit), effort)
        if let q = meta[HKMetadataKeyWeatherTemperature] as? HKQuantity, q.is(compatibleWith: .degreeCelsius()) {
            m[.temperature] = q.doubleValue(for: .degreeCelsius())
        }
        put(.humidity, quantity(HKMetadataKeyWeatherHumidity, .percent()).map { $0 * 100 })
        put(.aerobicEffect, band("aerobicEffect"))
        put(.anaerobicEffect, band("anaerobicEffect"))
        put(.trainingLoad, band("workoutLoad"))
        put(.recoveryHours, band("recoveryHours"))
        put(.vo2max, band("vo2Max"))
        out.metrics = m
        return out
    }

    /// True for a workout written from the band by this app: it is the band's,
    /// not one of the app's own exports.
    static func isBandWorkout(_ w: HKWorkout) -> Bool {
        w.metadata?[bandPrefix + "activeSeconds"] != nil
    }

    // MARK: Series on demand

    /// Heart rate, route and per-kilometre splits of one workout, read from
    /// Health when the session is opened. Samples come from the workout's own
    /// source when it wrote any, so a second device worn at the same time does
    /// not interleave its readings.
    func workoutSeries(uuid: String) async -> WorkoutSeries? {
        guard isAvailable, let id = UUID(uuidString: uuid) else { return nil }
        do {
            let found = try await HKSampleQueryDescriptor(
                predicates: [.workout(HKQuery.predicateForObject(with: id))], sortDescriptors: [], limit: 1
            ).result(for: store)
            guard let w = found.first else { return nil }
            var series = WorkoutSeries(start: w.startDate, end: w.endDate)
            let heartRate = try await samples(.heartRate, in: w, unit: Self.bpm)
            series.heartRate = Self.thin(heartRate.map { SeriesPoint(time: $0.0, value: $0.1) })
            let route = try await routeLocations(of: w)
            series.route = route.map { ($0.coordinate.latitude, $0.coordinate.longitude) }
            series.splits = route.count > 1
                ? Self.splits(route: route, heartRate: heartRate)
                : Self.splits(distance: try await distanceSamples(of: w), start: w.startDate, heartRate: heartRate)
            return series
        } catch {
            appLog.error("Workout series unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func samples(_ id: HKQuantityTypeIdentifier, in w: HKWorkout, unit: HKUnit) async throws -> [(Date, Double)] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        let window = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
        let all = try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: window)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        ).result(for: store)
        let own = all.filter { $0.sourceRevision.source == w.sourceRevision.source }
        return (own.count >= 2 ? own : all).map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
    }

    private func distanceSamples(of w: HKWorkout) async throws -> [(Date, Double)] {
        for id in [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling, .distanceSwimming] {
            let found = try await samples(id, in: w, unit: .meter())
            if !found.isEmpty { return found }
        }
        return []
    }

    private func routeLocations(of w: HKWorkout) async throws -> [CLLocation] {
        let routes = try await HKSampleQueryDescriptor(
            predicates: [.workoutRoute(HKQuery.predicateForObjects(from: w))], sortDescriptors: []
        ).result(for: store)
        var locations: [CLLocation] = []
        for route in routes {
            for try await location in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                locations.append(location)
            }
        }
        return locations.sorted { $0.timestamp < $1.timestamp }
    }

    /// Bucket averages, so a chart never draws thousands of points.
    private static func thin(_ points: [SeriesPoint]) -> [SeriesPoint] {
        guard points.count > chartPoints else { return points }
        let size = Int((Double(points.count) / Double(chartPoints)).rounded(.up))
        return stride(from: 0, to: points.count, by: size).map { i in
            let bucket = points[i..<min(i + size, points.count)]
            return SeriesPoint(time: bucket.first!.time, value: bucket.map(\.value).reduce(0, +) / Double(bucket.count))
        }
    }

    private static func meanHR(_ hr: [(Date, Double)], from: Date, to: Date) -> Double? {
        let v = hr.filter { $0.0 >= from && $0.0 < to }.map(\.1)
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    static func splits(route: [CLLocation], heartRate: [(Date, Double)]) -> [WorkoutSplit] {
        var out: [WorkoutSplit] = []
        var metres = 0.0, splitStart = route[0].timestamp
        for (prev, cur) in zip(route, route.dropFirst()) {
            metres += cur.distance(from: prev)
            if metres >= Double(out.count + 1) * metresPerSplit {
                out.append(WorkoutSplit(index: out.count + 1, seconds: cur.timestamp.timeIntervalSince(splitStart),
                                        avgHR: meanHR(heartRate, from: splitStart, to: cur.timestamp)))
                splitStart = cur.timestamp
            }
        }
        return out
    }

    static func splits(distance: [(Date, Double)], start: Date, heartRate: [(Date, Double)]) -> [WorkoutSplit] {
        var out: [WorkoutSplit] = []
        var metres = 0.0, splitStart = start
        for (time, d) in distance {
            metres += d
            if metres >= Double(out.count + 1) * metresPerSplit {
                out.append(WorkoutSplit(index: out.count + 1, seconds: time.timeIntervalSince(splitStart),
                                        avgHR: meanHR(heartRate, from: splitStart, to: time)))
                splitStart = time
            }
        }
        return out
    }

    // MARK: Writing an imported file into Health

    /// Puts a workout read from a file into Health with its heart rate and route,
    /// so it opens with the same charts as a watch's. Returns the new workout's
    /// UUID. Keyed by its start time: importing the file again adds nothing.
    func saveImported(_ p: ParsedWorkout, completion: @escaping (String?) -> Void) {
        Task {
            let uuid = try? await saveImported(p)
            await MainActor.run { completion(uuid) }
        }
    }

    private func saveImported(_ p: ParsedWorkout) async throws -> String? {
        guard isAvailable, p.durationSec > 0 else { return nil }
        let end = p.start.addingTimeInterval(TimeInterval(p.durationSec))
        let syncID = "fittracker.file.\(Int(p.start.timeIntervalSince1970))"
        let existing = try await HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncID]))],
            sortDescriptors: [], limit: 1
        ).result(for: store)
        if let w = existing.first { return w.uuid.uuidString }

        let sport = Sport(rawValue: p.sport) ?? .other
        var samples: [HKSample] = []
        if let t = HKObjectType.quantityType(forIdentifier: .heartRate) {
            samples += p.points.compactMap { pt in
                guard let time = pt.time, let hr = pt.hr, hr > 0 else { return nil }
                return HKQuantitySample(type: t, quantity: HKQuantity(unit: Self.bpm, doubleValue: hr), start: time, end: time)
            }
        }
        if let k = p.kcal, k > 0, let t = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            samples.append(HKQuantitySample(type: t, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(k)), start: p.start, end: end))
        }
        if let km = p.distanceKm, km > 0, let id = Self.distanceIdentifier(for: sport), let t = HKObjectType.quantityType(forIdentifier: id) {
            samples.append(HKQuantitySample(type: t, quantity: HKQuantity(unit: .meter(), doubleValue: km * 1000), start: p.start, end: end))
        }
        var metadata: [String: Any] = [HKMetadataKeySyncIdentifier: syncID, HKMetadataKeySyncVersion: 1]
        if let e = p.elevationM, e > 0 { metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .meter(), doubleValue: e) }
        let locations = p.points.compactMap { pt -> CLLocation? in
            guard let lat = pt.lat, let lon = pt.lon, let time = pt.time else { return nil }
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: pt.ele ?? 0,
                              horizontalAccuracy: 5, verticalAccuracy: pt.ele == nil ? -1 : 5, timestamp: time)
        }
        return try await writeWorkout(sport: sport, start: p.start, end: end, samples: samples,
                                      metadata: metadata, route: locations, device: nil)
    }

    /// One workout into Health: its samples, metadata and route. Returns its UUID.
    func writeWorkout(sport: Sport, start: Date, end: Date, samples: [HKSample], metadata: [String: Any] = [:],
                      route: [CLLocation], device: HKDevice?) async throws -> String? {
        guard isAvailable, end > start else { return nil }
        let config = HKWorkoutConfiguration()
        config.activityType = Self.activityType(for: sport)
        config.locationType = route.isEmpty ? .unknown : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: device)
        try await builder.beginCollection(at: start)
        if !samples.isEmpty { try await builder.addSamples(samples) }
        if !metadata.isEmpty { try await builder.addMetadata(metadata) }
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else { return nil }
        if !route.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: device)
            try await routeBuilder.insertRouteData(route)
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
        return workout.uuid.uuidString
    }
}
#endif
