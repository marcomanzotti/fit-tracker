import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Workout Live Activity (Lock Screen + Dynamic Island)
// Shows the running workout without unlocking the phone: elapsed clock, current
// exercise, sets done, and the rest countdown when one is running.
//
// This extension is deliberately self-contained — it can't see the app's Theme or
// localization (those live in the app target), so it carries the few colours and
// strings it needs, exactly as the watch app does.

private enum W {
    static let bg = Color(hex: "0b0b0d")
    static let txt = Color(hex: "f4efe6")
    static let sub = Color(hex: "8a857d")
    static let acc = Color(hex: "ffe000")
    static let blue = Color(hex: "4fb8c4")
}

/// Italian/English pair chosen from the device language — the extension has no
/// access to the app's runtime language table, and these are the only two strings
/// it shows.
private func wl(_ it: String, _ en: String) -> String {
    (Locale.preferredLanguages.first?.hasPrefix("it") == true) ? it : en
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(W.bg)
                .activitySystemActionForegroundColor(W.acc)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.planName.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color(hex: context.attributes.planColor))
                            .lineLimit(1)
                        if !context.state.exercise.isEmpty {
                            Text(context.state.exercise).font(.caption2).foregroundColor(W.sub).lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    clock(context).font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundColor(W.txt)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.setsDone) \(wl("serie", "sets"))", systemImage: "list.bullet")
                            .font(.caption2).foregroundColor(W.sub)
                        Spacer()
                        if let end = context.state.restEndsAt, end > Date() {
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass").font(.caption2)
                                Text(timerInterval: Date()...end, countsDown: true)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .frame(width: 44)
                            }
                            .foregroundColor(W.blue)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundColor(Color(hex: context.attributes.planColor))
            } compactTrailing: {
                compactTimer(context).font(.caption2.monospacedDigit()).frame(width: 42)
            } minimal: {
                Image(systemName: "dumbbell.fill").foregroundColor(Color(hex: context.attributes.planColor))
            }
            .keylineTint(Color(hex: context.attributes.planColor))
        }
    }

    // MARK: Lock Screen
    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        let planColor = Color(hex: context.attributes.planColor)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(planColor).frame(width: 7, height: 7)
                    Text(context.attributes.planName.uppercased())
                        .font(.caption.weight(.bold)).foregroundColor(planColor).lineLimit(1)
                }
                if context.state.exercise.isEmpty {
                    Text("\(context.state.setsDone) \(wl("serie", "sets"))")
                        .font(.caption2).foregroundColor(W.sub)
                } else {
                    Text(context.state.exercise).font(.footnote.weight(.semibold))
                        .foregroundColor(W.txt).lineLimit(1)
                    Text("\(context.state.setsDone) \(wl("serie", "sets"))")
                        .font(.caption2).foregroundColor(W.sub)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                clock(context).font(.title2.monospacedDigit().weight(.semibold)).foregroundColor(W.txt)
                if let end = context.state.restEndsAt, end > Date() {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass").font(.caption2)
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(width: 46, alignment: .trailing)
                    }
                    .foregroundColor(W.blue)
                } else {
                    Text(wl("in corso", "in progress")).font(.caption2).foregroundColor(W.sub)
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
    }

    /// Elapsed workout time, ticking on its own from the start date.
    private func clock(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Text {
        Text(context.state.startDate, style: .timer)
    }

    /// In the compact island the rest countdown is the more urgent number, so it
    /// takes the slot whenever a rest is running.
    private func compactTimer(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Text {
        if let end = context.state.restEndsAt, end > Date() {
            return Text(timerInterval: Date()...end, countsDown: true)
        }
        return Text(context.state.startDate, style: .timer)
    }
}

// MARK: - Next workout widget (Home Screen + Lock Screen)
// Next workout, streak and today's calories at a glance. It reads the snapshot the
// app writes into the shared App Group container; it never touches the data file.
private struct NextWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

private struct NextWorkoutProvider: TimelineProvider {
    private static let sample = WidgetSnapshot(nextName: "Push", nextColor: "ff5a52", nextIcon: "dumbbell.fill",
                                               streak: 5, kcalToday: 1_450, kcalTarget: 2_400)

    func placeholder(in context: Context) -> NextWorkoutEntry {
        NextWorkoutEntry(date: Date(), snapshot: Self.sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextWorkoutEntry) -> Void) {
        completion(NextWorkoutEntry(date: Date(), snapshot: context.isPreview ? Self.sample : WidgetSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextWorkoutEntry>) -> Void) {
        // The app reloads the widget whenever its data changes; nothing here
        // depends on the clock, so there is no refresh schedule.
        completion(Timeline(entries: [NextWorkoutEntry(date: Date(), snapshot: WidgetSnapshot.load())], policy: .never))
    }
}

private struct NextWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot?

    var body: some View {
        Group {
            if let snapshot {
                switch family {
                case .accessoryCircular:    circular(snapshot)
                case .accessoryRectangular: rectangular(snapshot)
                default:                    small(snapshot)
                }
            } else {
                Text(wl("Apri Fit Tracker", "Open Fit Tracker")).font(.caption).multilineTextAlignment(.center)
            }
        }
        .widgetBackground(W.bg)
    }

    private func nextName(_ s: WidgetSnapshot) -> String {
        s.nextName.isEmpty ? wl("Nessun allenamento", "No workout") : s.nextName
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(wl("PROSSIMO", "NEXT")).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(W.sub)
            HStack(spacing: 6) {
                Image(systemName: s.nextIcon).font(.system(size: 14, weight: .bold))
                Text(nextName(s).uppercased()).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundColor(Color(hex: s.nextColor))
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(s.streak)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(W.acc)
                Text(wl("giorni", "days")).font(.system(size: 11)).foregroundColor(W.sub)
            }
            Text("\(s.kcalToday) / \(s.kcalTarget) kcal").font(.system(size: 11, weight: .semibold))
                .foregroundColor(W.txt).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(nextName(s), systemImage: s.nextIcon).font(.headline).lineLimit(1)
            Text("\(s.streak) \(wl("giorni di fila", "day streak"))").font(.caption)
            Text("\(s.kcalToday) / \(s.kcalTarget) kcal").font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func circular(_ s: WidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill").font(.caption)
            Text("\(s.streak)").font(.system(size: 20, weight: .bold, design: .rounded))
        }
    }
}

private extension View {
    /// iOS 17 requires a container background for widgets; earlier systems take a plain one.
    @ViewBuilder func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            padding(14).background(color)
        }
    }
}

struct NextWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: NextWorkoutProvider()) { entry in
            NextWorkoutView(snapshot: entry.snapshot)
        }
        .configurationDisplayName(wl("Prossimo allenamento", "Next workout"))
        .description(wl("Prossimo allenamento, streak e calorie di oggi.", "Next workout, streak and today's calories."))
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct FitTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
        NextWorkoutWidget()
    }
}
