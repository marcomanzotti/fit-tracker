import AppIntents
import Foundation

// MARK: - Siri, Shortcuts and the Action button
// "Start Push", "Log weight 82.4", "How am I today?". The intents run in the app's
// process, on the same Store the app shows (registered at launch), so a weight
// logged by voice is on screen at once and never written by a second copy.

@MainActor
enum AppServices {
    static weak var store: Store?
}

/// A workout day or a cardio activity, as Siri and Shortcuts offer it.
struct WorkoutEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static let defaultQuery = WorkoutQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WorkoutQuery: EntityQuery {
    @MainActor
    private var all: [WorkoutEntity] {
        guard let store = AppServices.store else { return [] }
        return store.plans.map { WorkoutEntity(id: $0.id, name: $0.name) }
            + store.cardioTypes.map { WorkoutEntity(id: $0.id, name: $0.name) }
    }
    @MainActor func entities(for identifiers: [String]) async throws -> [WorkoutEntity] { all.filter { identifiers.contains($0.id) } }
    @MainActor func suggestedEntities() async throws -> [WorkoutEntity] { all }
}

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a workout"
    static let openAppWhenRun = true
    @Parameter(title: "Workout") var workout: WorkoutEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppServices.store?.startRequest = workout.id
        return .result()
    }
}

/// Starts the next workout of the plan; also behind the Control Center button.
struct StartNextWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start the next workout"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = AppServices.store, let next = store.nextUp() { store.startRequest = next.id }
        return .result()
    }
}

struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log weight"
    @Parameter(title: "Weight (kg)") var kilograms: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = AppServices.store else { return .result(dialog: "\(t("intent.not_ready"))") }
        guard Store.plausibleWeightKg.contains(kilograms) else { return .result(dialog: "\(t("intent.weight_bad"))") }
        store.saveCheckIn(weight: kilograms, sleep: nil)
        store.flushNow()
        return .result(dialog: "\(t("intent.weight_saved", trimNum((kilograms * 10).rounded() / 10)))")
    }
}

struct HowAmITodayIntent: AppIntent {
    static let title: LocalizedStringResource = "How am I today?"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = AppServices.store else { return .result(dialog: "\(t("intent.not_ready"))") }
        var parts: [String] = []
        if let score = store.readiness().score { parts.append(t("intent.readiness", score)) }
        if let left = store.recoveryEstimate()?.remaining { parts.append(left == 0 ? t("recovery.done") : t("recovery.left", left)) }
        if let next = store.nextUp() { parts.append(t("intent.next", next.name)) }
        return .result(dialog: "\(parts.isEmpty ? t("load.need_data") : parts.joined(separator: ". "))")
    }
}

/// The phrases Siri listens for. The app name must be in each; the Italian ones
/// come from it.lproj/AppShortcuts.strings.
struct FitTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWorkoutIntent(), phrases: ["Start \(\.$workout) in \(.applicationName)",
                                                            "Start \(\.$workout) with \(.applicationName)"],
                    shortTitle: "Start workout", systemImageName: "figure.strengthtraining.traditional")
        AppShortcut(intent: StartNextWorkoutIntent(), phrases: ["Start my next workout in \(.applicationName)"],
                    shortTitle: "Next workout", systemImageName: "play.fill")
        AppShortcut(intent: LogWeightIntent(), phrases: ["Log my weight in \(.applicationName)"],
                    shortTitle: "Log weight", systemImageName: "scalemass.fill")
        AppShortcut(intent: HowAmITodayIntent(), phrases: ["How am I today in \(.applicationName)"],
                    shortTitle: "How am I today", systemImageName: "heart.text.square.fill")
    }
}
