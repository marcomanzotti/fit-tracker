import SwiftUI

// MARK: - Apple Health history import (past days)
// The automatic sync only fills gaps in a rolling window, which makes a missing
// metric indistinguishable from a metric that was never authorized. This screen
// is both the feature and the diagnosis: pick a window, see how many days already
// carry each category, import (or re-import over stored values), and read back the
// last two weeks day by day. A category stuck at "0 / 90" points straight at a
// permission that's off in Settings › Privacy › Health.
struct HealthHistoryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var days = 365
    @State private var busy = false

    private let ranges = [30, 90, 365]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Text(t("hk.history_hint")).font(.system(size: 12)).foregroundColor(Theme.sub).lineSpacing(3)
                    rangeCard
                    coverageCard
                    recentDaysCard
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("hk.history").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                Text(rangeLabel).font(.system(size: 11)).foregroundColor(Theme.sub)
            }
            Spacer()
            Button { tap(); dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    private var rangeLabel: String {
        let cal = Calendar.current
        guard let from = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) else { return "" }
        return "\(fmtDM(isoFormatter.string(from: from))) → \(fmtDM(today()))"
    }

    // MARK: Range picker + import actions
    private var rangeCard: some View {
        Card {
            Lbl(text: t("hk.range"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 8) {
                ForEach(ranges, id: \.self) { r in
                    Button { tap(); days = r } label: {
                        Text(t("hk.range_days", r))
                            .font(.head(12, .semibold)).tracking(0.5)
                            .foregroundColor(days == r ? Theme.bg : Theme.txt)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(days == r ? Theme.acc : Theme.c2)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(days == r ? Color.clear : Theme.brd, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 12)

            BigButton(title: busy ? t("hk.importing") : t("hk.import_now"), color: Theme.acc) {
                runImport(overwrite: false)
            }
            .disabled(busy)
            .opacity(busy ? 0.6 : 1)

            Button { tap(); runImport(overwrite: true) } label: {
                Text(t("hk.reimport")).font(.head(13, .semibold)).foregroundColor(Theme.acc2)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                        .stroke(Theme.acc2.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .padding(.top, 9)

            Text(t("hk.reimport_hint")).font(.system(size: 9)).foregroundColor(Theme.sub).padding(.top, 8)
        }
    }

    private func runImport(overwrite: Bool) {
        guard !busy else { return }
        busy = true
        store.importHealthRange(days: days, overwrite: overwrite) { ok, written in
            busy = false
            guard ok else { toast.show(t("hk.denied")); return }
            haptic(written > 0 ? .success : .warning)
            toast.show(written > 0 ? t("hk.days_written", written) : t("hk.nothing_new"))
        }
    }

    // MARK: Per-category coverage — the diagnostic half of this screen
    private var coverageCard: some View {
        let cov = store.healthCoverage(from: fromDate, to: today())
        let selected = store.prefs.healthCategories
        return Card {
            HStack(spacing: 6) {
                Lbl(text: t("hk.coverage"), color: Theme.acc2)
                Spacer()
                Text("/ \(days)").font(.system(size: 11)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 10)
            ForEach(HealthCategory.allCases) { c in
                let n = cov[c.rawValue] ?? 0
                let on = selected.contains(c.rawValue)
                HStack(spacing: 10) {
                    Image(systemName: c.icon).font(.system(size: 13))
                        .foregroundColor(n > 0 ? Theme.good : (on ? Theme.red : Theme.sub))
                        .frame(width: 22)
                    Text(t(c.labelKey)).font(.system(size: 13)).foregroundColor(on ? Theme.txt : Theme.sub)
                    Spacer()
                    if !on {
                        Text("—").font(.system(size: 12)).foregroundColor(Theme.sub)
                    } else {
                        Text("\(n)").font(.num(15)).foregroundColor(n > 0 ? Theme.good : Theme.red)
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    if c != HealthCategory.allCases.last {
                        Rectangle().fill(Theme.brd).frame(height: 1)
                    }
                }
            }
        }
    }

    private var fromDate: String {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) ?? Date()
        return isoFormatter.string(from: d)
    }

    // MARK: Last 14 days, day by day — so "yesterday's steps" is one glance away
    private var recentDaysCard: some View {
        let cal = Calendar.current
        let recent: [DailyEntry] = (0..<14).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            let ds = isoFormatter.string(from: d)
            return store.dailyEntry(ds) ?? DailyEntry(date: ds)
        }
        return Card {
            Lbl(text: t("hk.recent_days"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 6) {
                Text("").frame(width: 42, alignment: .leading)
                colHead("figure.walk")
                colHead("flame.fill")
                colHead("bed.double.fill")
                colHead("waveform.path.ecg")
                colHead("heart.fill")
            }
            .padding(.bottom, 6)
            ForEach(recent) { e in
                HStack(spacing: 6) {
                    Text(fmtDM(e.date)).font(.system(size: 10, weight: .semibold))
                        .foregroundColor(e.date == today() ? Theme.acc : Theme.sub)
                        .frame(width: 42, alignment: .leading)
                    cell(e.steps.map { "\($0)" })
                    cell(e.activeKcal.map { "\($0)" })
                    cell(e.sleepHours.map { trimNum(($0 * 10).rounded() / 10) })
                    cell(e.hrvSDNN.map { trimNum($0.rounded()) })
                    cell(e.restHR.map { "\($0)" })
                }
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
            }
        }
    }

    private func colHead(_ icon: String) -> some View {
        Image(systemName: icon).font(.system(size: 10)).foregroundColor(Theme.sub)
            .frame(maxWidth: .infinity)
    }

    private func cell(_ v: String?) -> some View {
        Text(v ?? "—").font(.num(11)).foregroundColor(v == nil ? Theme.sub.opacity(0.5) : Theme.txt)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }
}
