import SwiftUI
import Combine
import UserNotifications

// MARK: - Rest timer
final class RestTimer: ObservableObject {
    @Published var remaining = 0
    @Published var total = 60
    @Published var active = false
    @Published var done = false
    private var cancellable: AnyCancellable?

    func start(_ seconds: Int) {
        total = seconds; remaining = seconds; active = true; done = false
        cancellable?.cancel()
        cancellable = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.remaining > 0 { self.remaining -= 1 }
                if self.remaining <= 0 {
                    self.done = true
                    self.cancellable?.cancel()
                    restDoneHaptic()
                }
            }
    }
    func reset() { start(total) }
    func stop() {
        cancellable?.cancel(); active = false; done = false
        RestNotifier.cancel()   // no alert for a rest that was cut short
    }

    var label: String {
        let m = remaining / 60, s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }
    var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }
}

// MARK: - Rest-timer notification
// The in-app countdown and its haptic only reach you with the phone in hand. A
// local notification covers the rest: pocketed phone, locked screen, another app.
// Local notifications need no capability beyond the user's permission, which we
// ask for the first time a rest actually starts rather than at launch.
enum RestNotifier {
    private static let id = "fittracker.rest"

    static func schedule(after seconds: Int) {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { post(after: seconds) }
                }
            case .authorized, .provisional, .ephemeral:
                post(after: seconds)
            default:
                break   // denied: the in-app timer and haptic still work
            }
        }
    }

    /// Cancel a pending alert — the rest was stopped or the workout ended, and a
    /// notification firing after that would be noise.
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func post(after seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = L.t("wk.rest_over")
        content.body = L.t("wk.rest_over_body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        // Only one rest is ever pending: a new set replaces the old alert.
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(req)
    }
}

// MARK: - Active workout session (survives tab switching)
// Holds the running workout so the user can freely navigate the app while a
// session is in progress. WorkoutView reads this instead of @State so switching
// tabs doesn't tear down the live log.
final class ActiveWorkout: ObservableObject {
    @Published var planId: String? = nil
    @Published var log: [LoggedExercise] = []
    @Published var startDate: Date? = nil
    /// True when the user backed out of the live view but the workout is still
    /// running in the background (the floating strip un-minimizes it).
    @Published var minimized: Bool = false

    var isActive: Bool { planId != nil }

    func start(plan: WorkoutPlan) {
        planId = plan.id
        minimized = false
        log = plan.exercises.map { ex in
            // Timed sets start EMPTY: the hold timer writes the seconds actually held,
            // and the plan's target drives that timer. Pre-filling the target used to
            // make an untouched set look already logged. Interval carries its HIIT
            // prescription (work/rest/rounds) forward unchanged.
            let sets = (0..<max(1, ex.sets)).map { _ in SetEntry() }
            let target: String
            switch ex.exKind {
            case .interval: target = "\(ex.rounds ?? 0)×\(ex.workSec ?? 0)s"
            case .timed:    target = "\(ex.sets)×\(ex.effectiveTargetSec)s"
            case .reps:     target = "\(ex.sets)×\(ex.reps)"
            }
            return LoggedExercise(name: ex.name,
                           sets: ex.exKind == .interval ? [] : sets,
                           notes: "",
                           target: target,
                           supersetGroup: ex.supersetGroup,
                           method: ex.method,
                           effortMode: ex.effortMode,
                           isBodyweight: ex.isBodyweight,
                           kind: ex.kind,
                           workSec: ex.workSec,
                           restSec: ex.restSec,
                           rounds: ex.rounds)
        }
        startDate = Date()
    }

    func end() {
        planId = nil
        log = []
        startDate = nil
        minimized = false
    }
}

// MARK: - Toast
final class ToastCenter: ObservableObject {
    @Published var message: String?
    private var work: DispatchWorkItem?

    func show(_ msg: String, duration: Double = 1.8) {
        message = msg
        work?.cancel()
        let w = DispatchWorkItem { [weak self] in withAnimation { self?.message = nil } }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: w)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.head(12, .semibold)).tracking(1)
            .foregroundColor(Theme.acc2)
            .padding(.vertical, 11).padding(.horizontal, 18)
            .background(Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.brd2, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }
}
