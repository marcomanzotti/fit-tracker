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
                    haptic(.success)
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

    var isActive: Bool { planId != nil }

    func start(plan: WorkoutPlan) {
        planId = plan.id
        log = plan.exercises.map { ex in
            LoggedExercise(name: ex.name,
                           sets: (0..<max(1, ex.sets)).map { _ in SetEntry() },
                           notes: "",
                           target: "\(ex.sets)×\(ex.reps)",
                           supersetGroup: ex.supersetGroup,
                           method: ex.method,
                           effortMode: ex.effortMode,
                           isBodyweight: ex.isBodyweight)
        }
        startDate = Date()
    }

    func end() {
        planId = nil
        log = []
        startDate = nil
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
