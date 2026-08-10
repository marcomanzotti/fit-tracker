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

private extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xff) / 255,
                  green: Double((v >> 8) & 0xff) / 255,
                  blue: Double(v & 0xff) / 255,
                  opacity: 1)
    }
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

@main
struct FitTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
