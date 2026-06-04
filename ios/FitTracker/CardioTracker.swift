import SwiftUI
import Combine
import CoreLocation

// MARK: - Active cardio session (survives tab switching, mirrors ActiveWorkout)
// Holds a running cardio activity so the user can move around the app while a
// session is in progress. WorkoutView reads this instead of @State so switching
// tabs doesn't tear down the live cardio screen.
final class ActiveCardio: ObservableObject {
    @Published var typeId: String? = nil
    @Published var startDate: Date? = nil
    @Published var minimized = false
    /// Accumulated seconds actually spent moving/active (pauses don't count).
    @Published var elapsedSec = 0
    @Published var paused = false
    /// GPS-tracked distance in km (outdoor sports). nil until the first fix.
    @Published var gpsDistanceKm: Double? = nil
    /// Current speed in m/s from the latest GPS fix (for live pace/speed).
    @Published var speedMS: Double = 0

    var isActive: Bool { typeId != nil }

    func start(_ type: CardioType) {
        typeId = type.id
        startDate = Date()
        minimized = false
        elapsedSec = 0
        paused = false
        gpsDistanceKm = nil
        speedMS = 0
    }

    func end() {
        typeId = nil
        startDate = nil
        minimized = false
        elapsedSec = 0
        paused = false
        gpsDistanceKm = nil
        speedMS = 0
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

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5   // metres between updates
    }

    func start() {
        running = true
        last = nil
        distanceKm = 0
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

    func stop() {
        running = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        authorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        if authorized && running { m.startUpdatingLocation() }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard running else { return }
        for loc in locs {
            // Reject stale or inaccurate fixes — they corrupt distance/speed.
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 30,
                  abs(loc.timestamp.timeIntervalSinceNow) < 10 else { continue }
            speedMS = max(0, loc.speed)
            if let prev = last {
                let step = loc.distance(from: prev)
                // Ignore tiny jitter while standing still.
                if step >= 2 { distanceKm += step / 1000 }
            }
            last = loc
        }
    }
}
