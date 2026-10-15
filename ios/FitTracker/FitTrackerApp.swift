import Band10Sync
import SwiftUI

extension BandSyncEngine {
    /// Copies the Xiaomi Smart Band 10's data into Apple Health over Bluetooth,
    /// without Mi Fitness. Idle until a band key is entered in the device guide.
    @MainActor static let fitTracker: BandSyncEngine = {
        var configuration = BandSyncEngine.Configuration(
            restoreIdentifier: "com.marco.manzotti.fittracker.band10",
            keychainService: "com.marco.manzotti.fittracker.band10"
        )
        configuration.phoneName = "FitTracker"
        return BandSyncEngine(configuration: configuration)
    }()
}

@main
struct FitTrackerApp: App {
    @StateObject private var store: Store
    @StateObject private var timer: RestTimer
    @StateObject private var toast: ToastCenter
    @StateObject private var activeWorkout: ActiveWorkout
    @StateObject private var activeCardio: ActiveCardio
    /// Restores a workout left in progress and keeps it on disk from here on.
    private let keeper: SessionKeeper

    init() {
        let store = Store(), timer = RestTimer(), toast = ToastCenter()
        let workout = ActiveWorkout(), cardio = ActiveCardio()
        _store = StateObject(wrappedValue: store)
        _timer = StateObject(wrappedValue: timer)
        _toast = StateObject(wrappedValue: toast)
        _activeWorkout = StateObject(wrappedValue: workout)
        _activeCardio = StateObject(wrappedValue: cardio)
        keeper = SessionKeeper(store: store, workout: workout, cardio: cardio, timer: timer, toast: toast)
        // Here and not in a view: iOS may relaunch the app in the background for
        // a Bluetooth event, without showing any window.
        // New band data in Health (sleep, steps...) is read back into the app at once.
        BandSyncEngine.fitTracker.onHealthDataWritten = { [weak store] in
            guard let store, store.prefs.healthKitEnabled else { return }
            store.syncHealth(days: 3)
        }
        BandSyncEngine.fitTracker.start()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environmentObject(timer)
                .environmentObject(toast)
                .environmentObject(activeWorkout)
                .environmentObject(activeCardio)
                .preferredColorScheme(.dark)
                .tint(Theme.acc)
                .keyboardDoneBar()
        }
    }
}
