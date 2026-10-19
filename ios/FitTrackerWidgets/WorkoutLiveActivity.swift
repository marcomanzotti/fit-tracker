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
    static let sub = Color(hex: "9a958d")
    static let acc = Color(hex: "ffe000")
    static let blue = Color(hex: "4fb8c4")
}

/// Italian/English pair in the app's language, which the app writes into the
/// widget snapshot; the device language before the app has written one.
private func wl(_ it: String, _ en: String, lang: String? = WidgetSnapshot.load()?.lang) -> String {
    let code = lang ?? (Locale.preferredLanguages.first?.hasPrefix("it") == true ? "it" : "en")
    return code == "it" ? it : en
}

/// The link the activity opens: the app shows the running session.
private let openSessionURL = URL(string: "fittracker://session")

/// A rest that has run out: shown as "go" until the next set.
private func restDone(_ state: WorkoutActivityAttributes.ContentState) -> Bool {
    guard let end = state.restEndsAt else { return false }
    return end <= Date()
}

private func symbol(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> String {
    context.attributes.icon ?? "dumbbell.fill"
}

/// The rest still to run, from one reading of the clock: reading it twice (once to
/// test, once to build the range) traps when the rest ends in between.
private func restRange(_ state: WorkoutActivityAttributes.ContentState) -> ClosedRange<Date>? {
    let now = Date()
    guard let end = state.restEndsAt, end > now else { return nil }
    return now...end
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .widgetURL(openSessionURL)
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
                        if let rest = restRange(context.state) {
                            HStack(spacing: 4) {
                                Image(systemName: "hourglass").font(.caption2)
                                Text(timerInterval: rest, countsDown: true)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .frame(width: 44)
                            }
                            .foregroundColor(W.blue)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: symbol(context)).foregroundColor(Color(hex: context.attributes.planColor))
            } compactTrailing: {
                compactTimer(context).font(.caption2.monospacedDigit()).frame(width: 42)
            } minimal: {
                Image(systemName: symbol(context)).foregroundColor(Color(hex: context.attributes.planColor))
            }
            .widgetURL(openSessionURL)
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
                if context.attributes.icon != nil {
                    EmptyView()
                } else if context.state.exercise.isEmpty {
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
                if let rest = restRange(context.state) {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass").font(.caption2)
                        Text(timerInterval: rest, countsDown: true)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(width: 46, alignment: .trailing)
                    }
                    .foregroundColor(W.blue)
                } else if restDone(context.state) {
                    Text(wl("VAI", "GO")).font(.caption.weight(.bold)).foregroundColor(W.acc)
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
        if let rest = restRange(context.state) {
            return Text(timerInterval: rest, countsDown: true)
        }
        if restDone(context.state) { return Text(wl("VAI", "GO")).foregroundColor(W.acc) }
        return Text(context.state.startDate, style: .timer)
    }
}

// MARK: - Next workout widget (Home Screen + Lock Screen)
// Next workout, streak and today's calories at a glance. It reads the snapshot the
// app writes into the shared App Group container; it never touches the data file.
/// Today as yyyy-MM-dd, the format of `WidgetSnapshot.date`.
private let snapshotDay: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

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
        // The app reloads the widget whenever its data changes. Past midnight the
        // snapshot speaks of yesterday until the app runs again, so the widget
        // redraws then and stops showing yesterday's calories as today's.
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [NextWorkoutEntry(date: Date(), snapshot: WidgetSnapshot.load())],
                            policy: .after(midnight)))
    }
}

private struct NextWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot?

    /// Text in the language of the snapshot already in hand.
    private func tr(_ it: String, _ en: String) -> String { wl(it, en, lang: snapshot?.lang) }

    /// A snapshot from an earlier day: its calories are not today's.
    private func kcalToday(_ s: WidgetSnapshot) -> Int {
        guard let day = s.date else { return s.kcalToday }
        return day == snapshotDay.string(from: Date()) ? s.kcalToday : 0
    }

    var body: some View {
        Group {
            if let snapshot {
                switch family {
                case .accessoryCircular:    circular(snapshot)
                case .accessoryRectangular: rectangular(snapshot)
                default:                    small(snapshot)
                }
            } else {
                Text(tr("Apri Fit Tracker", "Open Fit Tracker")).font(.caption).multilineTextAlignment(.center)
            }
        }
        .widgetBackground(W.bg)
    }

    private func nextName(_ s: WidgetSnapshot) -> String {
        s.nextName.isEmpty ? tr("Nessun allenamento", "No workout") : s.nextName
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("PROSSIMO", "NEXT")).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(W.sub)
            HStack(spacing: 6) {
                Image(systemName: s.nextIcon).font(.system(size: 14, weight: .bold))
                Text(nextName(s).uppercased()).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundColor(Color(hex: s.nextColor))
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(s.streak)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(W.acc)
                Text(tr("giorni", "days")).font(.system(size: 11)).foregroundColor(W.sub)
            }
            Text("\(kcalToday(s)) / \(s.kcalTarget) kcal").font(.system(size: 11, weight: .semibold))
                .foregroundColor(W.txt).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(nextName(s), systemImage: s.nextIcon).font(.headline).lineLimit(1)
            Text("\(s.streak) \(tr("giorni di fila", "day streak"))").font(.caption)
            Text("\(kcalToday(s)) / \(s.kcalTarget) kcal").font(.caption)
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
    func widgetBackground(_ color: Color) -> some View {
        containerBackground(for: .widget) { color }
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
