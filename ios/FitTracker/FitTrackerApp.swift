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
    @State private var store: Store
    @State private var timer: RestTimer
    @State private var toast: ToastCenter
    @StateObject private var activeWorkout: ActiveWorkout
    @StateObject private var activeCardio: ActiveCardio
    /// Restores a workout left in progress and keeps it on disk from here on.
    private let keeper: SessionKeeper

    init() {
        let store = Store(), timer = RestTimer(), toast = ToastCenter()
        let workout = ActiveWorkout(), cardio = ActiveCardio()
        _store = State(initialValue: store)
        _timer = State(initialValue: timer)
        _toast = State(initialValue: toast)
        _activeWorkout = StateObject(wrappedValue: workout)
        _activeCardio = StateObject(wrappedValue: cardio)
        keeper = SessionKeeper(store: store, workout: workout, cardio: cardio, timer: timer, toast: toast)
        AppServices.store = store      // Siri and Shortcuts act on this same Store
        // Here and not in a view: iOS may relaunch the app in the background for
        // a Bluetooth event, without showing any window.
        // New band data in Health (sleep, steps...) is read back into the app at once.
        BandSyncEngine.fitTracker.onHealthDataWritten = { [weak store] in
            guard let store, store.prefs.healthKitEnabled else { return }
            store.syncHealth(days: Store.healthResyncDays)
        }
        BandSyncEngine.fitTracker.start()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .environment(timer)
                .environment(toast)
                .environmentObject(activeWorkout)
                .environmentObject(activeCardio)
                .preferredColorScheme(.dark)
                .tint(Theme.acc)
                .keyboardDoneBar()
        }
    }
}
