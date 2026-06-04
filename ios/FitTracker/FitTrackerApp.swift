import SwiftUI

@main
struct FitTrackerApp: App {
    @StateObject private var store = Store()
    @StateObject private var timer = RestTimer()
    @StateObject private var toast = ToastCenter()
    @StateObject private var activeWorkout = ActiveWorkout()
    @StateObject private var activeCardio = ActiveCardio()

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
