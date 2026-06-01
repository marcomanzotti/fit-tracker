import SwiftUI

@main
struct FitTrackerWatchApp: App {
    @StateObject private var link = WatchLink.shared
    @StateObject private var workout = WorkoutManager()

    init() { WatchLink.shared.activate() }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(link)
                .environmentObject(workout)
                .tint(T.acc)
        }
    }
}

// MARK: - Root: routes between the activity picker, the live workout and summary
struct WatchRootView: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            switch workout.phase {
            case .idle:                   ActivityPickerView()
            case .requesting:             PreparingView()
            case .active:                 LiveWorkoutView()
            case .ended:                  SummaryView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: workout.phase)
    }
}

struct PreparingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(T.acc)
            Text(wt("preparing").uppercased()).font(.head(12, .semibold)).tracking(1).foregroundColor(T.sub)
            Text(wt("auth_needed")).font(.system(size: 11)).foregroundColor(T.sub)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
