import SwiftUI

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
        }
    }
}
