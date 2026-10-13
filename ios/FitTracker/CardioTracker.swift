import SwiftUI
import Combine
import CoreLocation

// MARK: - Active cardio session
// Holds a running cardio activity: its clock, its GPS tracker and whatever a
// paired watch reports. The clock is derived from dates and the tracker lives
// here rather than in the live screen, so time and distance keep accumulating
// while that screen is minimised, another tab is showing or the phone is locked.
final class ActiveCardio: ObservableObject {
    @Published private(set) var type: CardioType?
    @Published private(set) var startDate: Date?
    @Published var minimized = false
    @Published private(set) var paused = false
    /// GPS-tracked distance in km (outdoor sports). nil until the first fix.
    @Published private(set) var gpsDistanceKm: Double?
    /// Current speed in m/s from the latest GPS fix (for live pace/speed).
    @Published private(set) var speedMS: Double = 0
    @Published private(set) var gpsAuthorized = false
    /// Set at launch when a session was brought back from disk; cleared once shown.
    @Published var restored = false
    /// The finished watch workout for this activity, once it arrives. Its numbers
    /// are measured, so they win over the phone's when the session is saved.
    @Published private(set) var watchResult: WatchResult?

    /// Seconds from running stretches already closed by a pause.
    private var accumulatedSec: TimeInterval = 0
    /// Start of the stretch running now; nil while paused.
    private var runningSince: Date?
    private var watchAvgHR: Int?
    private var watchKcal: Int?

    /// Gone for no longer than this, the session resumes as if never interrupted;
    /// beyond it the clock comes back paused at the last save.
    static let resumeGapSec: TimeInterval = 10 * 60

    private let clock: () -> Date
    private let tracksLocation: Bool
    private var bag = Set<AnyCancellable>()
    /// Created the first time an outdoor session needs it, so launching the app
    /// never touches CoreLocation.
    private lazy var gps: LocationTracker? = {
        guard tracksLocation else { return nil }
        let tracker = LocationTracker()
        tracker.$distanceKm.sink { [weak self] km in self?.gpsDistanceKm = km > 0 ? km : nil }.store(in: &bag)
        tracker.$speedMS.sink { [weak self] speed in self?.speedMS = speed }.store(in: &bag)
        tracker.$authorized.sink { [weak self] ok in self?.gpsAuthorized = ok }.store(in: &bag)
        return tracker
    }()

    /// Called synchronously when a session starts or ends (set by SessionKeeper).
    var onBoundary: () -> Void = {}

    /// `tracksLocation: false` leaves CoreLocation out entirely (tests).
    init(clock: @escaping () -> Date = Date.init, tracksLocation: Bool = true) {
        self.clock = clock
        self.tracksLocation = tracksLocation
    }

    var typeId: String? { type?.id }
    /// Id the watch knows this activity by.
    var activityId: String? { type.map { "cardio-\($0.id)" } }
    var isActive: Bool { type != nil }
    /// Outdoor sports use GPS; indoor/other skip it (no permission prompt).
    var usesGPS: Bool {
        switch type?.sportType {
        case .running, .walking, .cycling: return true
        default: return false
        }
    }

    /// Active (non-paused) seconds so far.
    func elapsedSec(at now: Date? = nil) -> Int {
        let running = runningSince.map { (now ?? clock()).timeIntervalSince($0) } ?? 0
        return max(0, Int(accumulatedSec + running))
    }

    func start(_ type: CardioType) {
        clear()
        self.type = type
        startDate = clock()
        runningSince = startDate
        if usesGPS { gps?.start() }
        onBoundary()
    }

    func togglePause() {
        guard isActive else { return }
        let now = clock()
        if let since = runningSince {
            accumulatedSec += now.timeIntervalSince(since)
            runningSince = nil
            if usesGPS { gps?.pause() }
        } else {
            runningSince = now
            if usesGPS { gps?.resume() }
        }
        paused = runningSince == nil
    }

    func end() {
        clear()
        onBoundary()
    }

    private func clear() {
        if usesGPS { gps?.stop() }
        type = nil
        startDate = nil
        minimized = false
        paused = false
        gpsDistanceKm = nil
        speedMS = 0
        restored = false
        watchResult = nil
        accumulatedSec = 0
        runningSince = nil
        watchAvgHR = nil
        watchKcal = nil
    }

    // MARK: Draft
    var draft: WorkoutDraft.Cardio? {
        guard let type, let startDate else { return nil }
        return WorkoutDraft.Cardio(type: type, startDate: startDate, accumulatedSec: accumulatedSec,
                                   runningSince: runningSince, distanceKm: gpsDistanceKm)
    }

    /// Bring a session back. What happened while the app was gone is unknown: after
    /// a short gap the clock carries on, after a long one it comes back paused at
    /// the moment of the last save instead of inventing hours of activity.
    func restore(_ draft: WorkoutDraft.Cardio, savedAt: Date) {
        clear()
        type = draft.type
        startDate = draft.startDate
        accumulatedSec = draft.accumulatedSec
        if let since = draft.runningSince {
            if clock().timeIntervalSince(savedAt) <= Self.resumeGapSec {
                runningSince = since
            } else {
                accumulatedSec += max(0, savedAt.timeIntervalSince(since))
            }
        }
        paused = runningSince == nil
        gpsDistanceKm = draft.distanceKm
        if usesGPS {
            gps?.start(from: draft.distanceKm ?? 0)
            if paused { gps?.pause() }
        }
        restored = true
    }

    // MARK: Watch mirroring
    /// The watch's clock is the source of truth while it streams: re-anchor ours to
    /// it, so the display keeps ticking between samples instead of jumping.
    func absorb(live s: WatchLiveSample) {
        guard s.activityId == activityId else { return }
        if s.elapsedSec > 0 {
            accumulatedSec = TimeInterval(s.elapsedSec)
            if runningSince != nil { runningSince = clock() }
        }
        if s.avgHR > 0 { watchAvgHR = s.avgHR }
        if s.kcal > 0 { watchKcal = s.kcal }
        objectWillChange.send()
    }

    func absorb(result r: WatchResult) {
        guard r.activityId == activityId else { return }
        watchResult = r
    }

    // MARK: Finishing
    /// Distance to show and save: the watch's when it measured one, else GPS.
    func distanceKm(live: WatchLiveSample?) -> Double? {
        if let d = watchResult?.distanceKm, d > 0 { return d }
        if let d = live?.distanceKm, d > 0, live?.activityId == activityId { return d }
        return gpsDistanceKm
    }

    /// The session to save, or nil when no time was recorded. `caloriesManual` is
    /// set only from the watch's measured energy; the caller adds an estimate.
    func finishedSession(live: WatchLiveSample? = nil) -> WorkoutSession? {
        guard let type, let startDate, let activityId else { return nil }
        let seconds = (watchResult?.durationSec).flatMap { $0 > 0 ? $0 : nil } ?? elapsedSec()
        guard seconds > 0 else { return nil }
        var session = WorkoutSession(date: isoFormatter.string(from: startDate), planId: activityId,
                                     planName: type.name, planColor: type.color)
        if let id = (watchResult?.id).flatMap(UUID.init(uuidString:)) { session.id = id }
        session.sport = type.sport
        session.durationSec = seconds
        session.avgHR = (watchResult?.avgHR ?? watchAvgHR).flatMap { $0 > 0 ? $0 : nil }
        session.maxHRSes = (watchResult?.maxHR).flatMap { $0 > 0 ? $0 : nil }
        session.distanceKm = distanceKm(live: live)
        session.caloriesManual = (watchResult?.activeKcal ?? watchKcal).flatMap { $0 > 0 ? $0 : nil }
        return session
    }
}

// MARK: - GPS distance/speed tracker (outdoor cardio)
// A thin CoreLocation wrapper that accumulates distance between successive,
// accurate fixes and exposes the latest speed. Only used for outdoor sports
// (run / walk / cycle); indoor activities skip it entirely so no location
// permission prompt appears. Tracking only runs between start() and stop().
final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var distanceKm: Double = 0
    @Published var speedMS: Double = 0
    @Published var authorized = false

    private let manager = CLLocationManager()
    private var last: CLLocation?
    private var running = false
    private var paused = false

    private static let maxAccuracyMeters = 30.0
    private static let maxFixAgeSeconds = 10.0
    /// Steps shorter than this are standing-still jitter.
    private static let minStepMeters = 2.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5   // metres between updates
        // Keep measuring with the screen locked or another app in front. Setting
        // this without the "location" background mode in Info.plist is a crash, so
        // it is only turned on when the mode is really declared.
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
            manager.showsBackgroundLocationIndicator = true
        }
    }

    /// Start tracking. `from` carries over the distance of a restored session.
    func start(from km: Double = 0) {
        running = true
        paused = false
        last = nil
        distanceKm = km
        speedMS = 0
        // Ask for permission the first time; updates begin once granted.
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            authorized = true
            manager.startUpdatingLocation()
        }
    }

    /// Stop counting distance without ending the session.
    func pause() {
        paused = true
        last = nil       // the move made while paused must not be added on resume
        speedMS = 0
    }

    func resume() { paused = false }

    func stop() {
        running = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        if authorized && running { m.startUpdatingLocation() }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        appLog.error("Location update failed: \(String(describing: error), privacy: .public)")
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard running, !paused else { return }
        for loc in locs {
            // Reject stale or inaccurate fixes — they corrupt distance/speed.
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < Self.maxAccuracyMeters,
                  abs(loc.timestamp.timeIntervalSinceNow) < Self.maxFixAgeSeconds else { continue }
            speedMS = max(0, loc.speed)
            if let prev = last {
                let step = loc.distance(from: prev)
                if step >= Self.minStepMeters { distanceKm += step / 1000 }
            }
            last = loc
        }
    }
}
