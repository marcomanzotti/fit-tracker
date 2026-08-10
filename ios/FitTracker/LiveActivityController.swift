import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity control (app side)
// Starts, updates and ends the Lock Screen / Dynamic Island activity for a running
// workout. Every entry point is a no-op when Live Activities are unavailable or the
// user turned the setting off, so callers never need to check first.
//
// Updates are pushed only on real events (exercise changed, set logged, rest
// started/stopped). The clock and the rest countdown are rendered from dates by
// SwiftUI itself, so no per-second update is needed — which is what keeps this
// inside the system's update budget.
//
// Note: every ActivityKit type is written module-qualified. The app already has
// its own `Activity` (the TDEE activity level in Models.swift), which shadows
// ActivityKit's inside this module.
enum LiveActivityController {
    /// Id of the activity THIS session started. Ending an activity is asynchronous,
    /// so right after a restart the system list can still contain the outgoing one;
    /// looking up by id means an update can never land on the activity we just
    /// dismissed.
    private static var activeId: String?

    static func start(planName: String, planColor: String, startDate: Date, enabled: Bool) {
        #if canImport(ActivityKit)
        guard enabled, #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A stale activity from a crashed session would otherwise sit there forever.
        endAll()
        let attrs = WorkoutActivityAttributes(planName: planName, planColor: planColor)
        let state = WorkoutActivityAttributes.ContentState(
            startDate: startDate, exercise: "", setsDone: 0, restEndsAt: nil)
        let activity = try? ActivityKit.Activity<WorkoutActivityAttributes>.request(
            attributes: attrs,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil)
        activeId = activity?.id
        #endif
    }

    static func update(exercise: String, setsDone: Int, restEndsAt: Date?) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), let id = activeId,
              let activity = ActivityKit.Activity<WorkoutActivityAttributes>.activities
                  .first(where: { $0.id == id }) else { return }
        var state = activity.content.state
        state.exercise = exercise
        state.setsDone = setsDone
        state.restEndsAt = restEndsAt
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        #endif
    }

    static func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        endAll()
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func endAll() {
        activeId = nil
        for a in ActivityKit.Activity<WorkoutActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate) }
        }
    }
    #endif
}
