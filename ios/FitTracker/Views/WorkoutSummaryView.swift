import SwiftUI

// MARK: - End-of-workout summary
// What the session just saved amounted to, shown once after Finish: time, sets,
// volume against the last time this plan was trained, records beaten, energy.

struct WorkoutSummary: Identifiable, Equatable {
    struct Record: Identifiable, Equatable {
        var name: String
        var weight: Double
        var previous: Double
        var id: String { name }
    }

    let id = UUID()
    var planName: String
    var planColor: String
    var durationSec: Int?
    var sets: Int
    var volume: Double
    /// Volume of the previous session of the same plan; nil the first time.
    var previousVolume: Double?
    var records: [Record]
    var kcal: Int
    var trimp: Double?
    /// A run or a ride shows its distance instead of sets and volume.
    var cardio = false
    var distanceKm: Double?

    /// Change in volume against last time, as a fraction (0.08 = +8%).
    var volumeChange: Double? {
        guard let previousVolume, previousVolume > 0 else { return nil }
        return (volume - previousVolume) / previousVolume
    }

    /// Build the summary. `previous` and `recordBefore` must describe the history
    /// from before this session was saved, otherwise it would be compared with itself.
    static func make(session: WorkoutSession, previous: WorkoutSession?,
                     recordBefore: (String) -> Double, kcal: Int, trimp: Double?) -> WorkoutSummary {
        let records = session.exercises.compactMap { exercise -> Record? in
            let before = recordBefore(exercise.name)
            // A first-ever log is not a record beaten: there was nothing to beat.
            guard before > 0, exercise.maxWeight > before else { return nil }
            return Record(name: exercise.name, weight: exercise.maxWeight, previous: before)
        }
        return WorkoutSummary(planName: session.planName, planColor: session.planColor,
                              durationSec: session.durationSeconds, sets: session.totalSets,
                              volume: session.volume, previousVolume: previous?.volume,
                              records: records, kcal: kcal, trimp: trimp,
                              cardio: session.sportType.isCardio, distanceKm: session.distanceKm)
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { Color(hex: summary.planColor) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if summary.cardio {
                        StatTile(label: t("wk.distance"), value: summary.distanceKm.map { trimNum(Units.distOut($0)) } ?? "—",
                                 unit: Units.distLabel, valueColor: Theme.txt)
                    } else {
                        HStack(spacing: 9) {
                            StatTile(label: t("sum.sets"), value: "\(summary.sets)", valueColor: Theme.txt)
                            StatTile(label: t("wk.vol"), value: "\(Int(summary.volume))", unit: "kg",
                                     valueColor: Theme.txt, note: volumeNote, info: .volume)
                        }
                    }
                    HStack(spacing: 9) {
                        StatTile(label: t("wk.calories"), value: "\(summary.kcal)", unit: "kcal",
                                 valueColor: Theme.acc, info: .calories)
                        StatTile(label: "TRIMP", value: summary.trimp.map { "\(Int($0.rounded()))" } ?? "—",
                                 valueColor: Theme.acc2, info: .trimp)
                    }
                    if !summary.records.isEmpty { recordsCard }
                    BigButton(title: t("sum.done"), color: accent) { dismiss() }
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18).padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(t("sum.title").uppercased()).font(.head(11, .semibold)).tracking(2).foregroundColor(Theme.sub)
            Text(summary.planName.uppercased()).font(.head(24, .bold)).tracking(0.5).foregroundColor(accent)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let seconds = summary.durationSec {
                Text(fmtDuration(seconds)).font(.num(40)).foregroundColor(Theme.txt).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26).padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    /// "+8% vs last time", or nothing the first time a plan is trained.
    private var volumeNote: String? {
        guard let change = summary.volumeChange else { return nil }
        let percent = Int((change * 100).rounded())
        return "\(percent >= 0 ? "+" : "")\(percent)% \(t("sum.vs_last"))"
    }

    private var recordsCard: some View {
        Card(accent: Theme.acc) {
            Lbl(text: t("sum.records"), color: Theme.acc2).padding(.bottom, 8)
            ForEach(summary.records) { record in
                HStack {
                    Text(record.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                        .lineLimit(1)
                    Spacer()
                    Text("\(trimNum(record.previous)) → \(trimNum(record.weight)) kg")
                        .font(.num(14)).foregroundColor(Theme.acc)
                }
                .padding(.vertical, 5)
            }
        }
    }
}
