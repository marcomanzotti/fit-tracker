import SwiftUI
import Combine

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
    func stop() { cancellable?.cancel(); active = false; done = false }

    var label: String {
        let m = remaining / 60, s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }
    var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }
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
            // A timed hold seeds each set's `seconds` from the plan's target so the
            // user only adjusts what they actually held; interval carries its HIIT
            // prescription (work/rest/rounds) forward unchanged.
            let targetSec = ex.exKind == .timed ? Double(ex.reps.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.max() ?? 0) : 0
            let sets = (0..<max(1, ex.sets)).map { _ in
                SetEntry(seconds: ex.exKind == .timed && targetSec > 0 ? targetSec : nil)
            }
            return LoggedExercise(name: ex.name,
                           sets: ex.exKind == .interval ? [] : sets,
                           notes: "",
                           target: ex.exKind == .interval ? "\(ex.rounds ?? 0)×\(ex.workSec ?? 0)s" : "\(ex.sets)×\(ex.reps)",
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
