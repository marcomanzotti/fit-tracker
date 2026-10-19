import SwiftUI
import WidgetKit

// MARK: - Watch face: next workout and readiness
// A complication and Smart Stack card. It reads what the watch app keeps in the
// shared App Group container (WatchGlance), sent by the phone with the catalog.

private struct GlanceEntry: TimelineEntry {
    let date: Date
    let glance: WatchGlance?
}

private struct GlanceProvider: TimelineProvider {
    private static let sample = WatchGlance(nextName: "Push", nextColor: "ff5a52", nextIcon: "dumbbell.fill",
                                            readiness: 72, lang: "it")

    func placeholder(in context: Context) -> GlanceEntry { GlanceEntry(date: Date(), glance: Self.sample) }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: Date(), glance: context.isPreview ? Self.sample : WatchGlance.load()))
    }

    /// The watch app reloads the timeline when new data arrives; until then it holds.
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        completion(Timeline(entries: [GlanceEntry(date: Date(), glance: WatchGlance.load())], policy: .never))
    }
}

private func wl(_ it: String, _ en: String, _ glance: WatchGlance?) -> String {
    (glance?.lang ?? (Locale.preferredLanguages.first?.hasPrefix("it") == true ? "it" : "en")) == "it" ? it : en
}

private struct GlanceView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlanceEntry

    var body: some View {
        let g = entry.glance
        let color = Color(hex: g?.nextColor ?? "ffe000")
        switch family {
        case .accessoryCircular:
            VStack(spacing: 1) {
                Image(systemName: g?.nextIcon ?? "dumbbell.fill").font(.system(size: 13, weight: .bold))
                Text(g?.readiness.map(String.init) ?? "—").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .widgetAccentable()
        case .accessoryInline:
            Text(g.map { $0.nextName.isEmpty ? wl("Riposo", "Rest", $0) : $0.nextName } ?? "Fit Tracker")
        case .accessoryCorner:
            Image(systemName: g?.nextIcon ?? "dumbbell.fill").font(.system(size: 18, weight: .bold))
                .widgetLabel(g?.readiness.map { "\($0)" } ?? "—")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(wl("PROSSIMO", "NEXT", g)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Label(g.map { $0.nextName.isEmpty ? wl("Riposo", "Rest", $0) : $0.nextName } ?? "—",
                      systemImage: g?.nextIcon ?? "dumbbell.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(color).widgetAccentable()
                if let r = g?.readiness {
                    Text("\(wl("Prontezza", "Readiness", g)) \(r)/100").font(.system(size: 12, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GlanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FitTrackerGlance", provider: GlanceProvider()) { entry in
            GlanceView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fit Tracker")
        .description("Next workout and readiness · Prossimo allenamento e prontezza")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct FitTrackerWatchWidgetsBundle: WidgetBundle {
    var body: some Widget { GlanceWidget() }
}
