import SwiftUI

@main
struct FitTrackerApp: App {
    @StateObject private var store = Store()
    @StateObject private var timer = RestTimer()
    @StateObject private var toast = ToastCenter()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environmentObject(timer)
                .environmentObject(toast)
                .preferredColorScheme(.dark)
                .tint(Theme.acc)
        }
    }
}
