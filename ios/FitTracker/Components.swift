import SwiftUI
import UIKit

// MARK: - Card container
struct Card<Content: View>: View {
    var accent: Color? = nil
    var bg: Color = Theme.c1
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.vertical, 15).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .overlay(alignment: .leading) {
                if let accent { Rectangle().fill(accent).frame(width: 3) }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.brd, lineWidth: 1)
            )
    }
}

// MARK: - Section / card label
struct Lbl: View {
    let text: String
    var color: Color = Theme.sub
    var body: some View {
        Text(text.uppercased())
            .font(.head(10, .semibold))
            .tracking(2)
            .foregroundColor(color)
    }
}

// MARK: - Info button + explanation popup (for scientific metrics)
// Tapping any metric's small "i" opens a sheet explaining what it means, how it
// is computed and how to read it. Content comes from localized keys
// "info.<id>.title" / "info.<id>.body".
struct InfoButton: View {
    let id: String                 // e.g. "acwr" -> info.acwr.title / info.acwr.body
    var color: Color = Theme.sub
    var size: CGFloat = 26         // tap-target size (shrink to keep label rows aligned)
    @State private var show = false
    var body: some View {
        Button { tap(); show = true } label: {
            Image(systemName: "info.circle").font(.system(size: 13)).foregroundColor(color)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $show) { InfoSheet(id: id) }
    }
}

struct InfoSheet: View {
    let id: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(t("info.\(id).title")).font(.head(20, .bold)).tracking(0.3)
                            .foregroundColor(Theme.acc).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button { tap(); dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    Text(t("info.\(id).body"))
                        .font(.system(size: 14)).foregroundColor(Theme.txt).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

/// A card/section label with an inline info button on the right.
struct InfoLbl: View {
    let text: String
    let info: String               // info id
    var color: Color = Theme.sub
    var body: some View {
        HStack(spacing: 4) {
            Lbl(text: text, color: color)
            InfoButton(id: info, color: color)
            Spacer()
        }
    }
}

// MARK: - Small stat tile
struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var valueColor: Color = Theme.txt
    var note: String? = nil
    var info: String? = nil        // optional info-popup id
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                // Keep multi-word labels ("Weekly load", "Monotony") on a single
                // line: shrink to fit rather than wrapping a syllable below.
                Text(label.uppercased())
                    .font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    .lineLimit(1).minimumScaleFactor(0.6).fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                if let info { InfoButton(id: info) }
            }
            // Reserve 26px for the info-button row so tiles without a button
            // keep the same top-to-number distance as those that have one.
            .frame(minHeight: 26, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // Pin the big number to one line at a fixed size: a value with a
                // unit ("87,5") and a bare value ("12", Sessions) then render at the
                // same size and baseline across all tiles in a row.
                Text(value).font(.num(30)).foregroundColor(valueColor)
                    .lineLimit(1).minimumScaleFactor(0.5)
                if let unit { Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub) }
            }
            if let note {
                // Reserve two lines so tiles in a row keep identical heights even
                // when one note wraps and another is a single word.
                Text(note).font(.system(size: 10)).foregroundColor(Theme.sub)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(.vertical, 13).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }
}

// MARK: - Progress bar
struct Bar: View {
    var value: Double            // 0...1
    var gradient: [Color] = [Theme.acc, Theme.acc2]
    var height: CGFloat = 7
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.mut)
                Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Circular goal ring
struct GoalRing: View {
    var value: Double            // 0...1
    var color: Color = Theme.acc
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle().stroke(Theme.c3, lineWidth: 6)
            Circle().trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((value * 100).rounded()))%").font(.num(17)).foregroundColor(color)
                Text("DONE").font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pills, badges, tags
struct Tag: View {
    let text: String
    var color: Color = Theme.sub
    var bg: Color = Theme.mut
    var body: some View {
        Text(text).font(.num(11)).foregroundColor(color)
            .padding(.vertical, 4).padding(.horizontal, 9)
            .background(bg).clipShape(Capsule())
    }
}

struct Badge: View {
    let text: String
    var color: Color = Theme.acc2
    var bg: Color = Theme.acc.opacity(0.14)
    var body: some View {
        Text(text.uppercased()).font(.head(11, .semibold)).tracking(0.8).foregroundColor(color)
            .padding(.vertical, 4).padding(.horizontal, 10)
            .background(bg).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Buttons
struct FilledButton: View {
    let title: String
    var color: Color = Theme.acc
    var action: () -> Void
    var body: some View {
        Button { tap(); action() } label: {
            Text(title).font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        }
    }
}

struct BigButton: View {
    let title: String
    var color: Color = Theme.acc
    var action: () -> Void
    var body: some View {
        Button { tap(); action() } label: {
            Text(title.uppercased()).font(.head(16, .bold)).tracking(3)
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }
}

struct GhostButton: View {
    let title: String
    var color: Color = Theme.sub
    var action: () -> Void
    var body: some View {
        Button { tap(); action() } label: {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
                .padding(.vertical, 8).padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Theme.c2)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        }
    }
}

// MARK: - Uniform field label
/// A field caption with an optional inline info button, pinned to a fixed height
/// and a single line. Because the height never changes whether or not an info
/// button is present, input boxes in adjacent columns always start at the same
/// vertical position and keep equal sizes.
struct FieldLabel: View {
    let text: String
    var info: String? = nil
    init(_ text: String, info: String? = nil) { self.text = text; self.info = info }
    var body: some View {
        HStack(spacing: 2) {
            Text(text.uppercased())
                .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let info { InfoButton(id: info, size: 18) }
            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }
}

// MARK: - Duration field (H / M / S)
/// Three integer boxes (hours / minutes / seconds) bound to a total-seconds value.
/// Replaces the old "minutes only" entry so a 1h28m ride is logged precisely and
/// every duration-based formula (TRIMP, pace, calories) gets the exact time.
struct HMSField: View {
    let label: String
    @Binding var seconds: Int?
    var info: String? = nil

    @State private var h = ""
    @State private var m = ""
    @State private var s = ""
    @State private var synced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(label, info: info)
            HStack(spacing: 8) {
                box($h, "dur.h", "0")
                box($m, "dur.m", "30")
                box($s, "dur.s", "00")
            }
        }
        .onAppear { if !synced { sync(); synced = true } }
        .onChange(of: h) { _ in recompute() }
        .onChange(of: m) { _ in recompute() }
        .onChange(of: s) { _ in recompute() }
    }

    private func box(_ b: Binding<String>, _ unitKey: String, _ ph: String) -> some View {
        VStack(spacing: 4) {
            TextField("", text: b, prompt: Text(ph).foregroundColor(Theme.sub))
                .keyboardType(.numberPad).multilineTextAlignment(.center)
                .foregroundColor(Theme.txt).font(.system(size: 16, weight: .medium))
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(Theme.c2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            Text(t(unitKey)).font(.head(8, .semibold)).tracking(1).foregroundColor(Theme.sub)
        }
    }

    private func recompute() {
        let total = Int(pf(h)) * 3600 + Int(pf(m)) * 60 + Int(pf(s))
        seconds = total > 0 ? total : nil
    }
    private func sync() {
        guard let sec = seconds, sec > 0 else { return }
        if sec >= 3600 { h = "\(sec / 3600)" }
        m = "\((sec % 3600) / 60)"
        if sec % 60 != 0 { s = "\(sec % 60)" }
    }
}

// MARK: - Pace / speed field
/// Per-sport pace entry: cycling shows km/h, swimming min/100m, the rest min/km.
/// The box auto-fills (as a placeholder) from distance + duration; typing a value
/// overrides it. The caption shows the readable auto value (mm:ss for min-based).
struct PaceField: View {
    let session: WorkoutSession
    @Binding var manual: Double?

    @State private var text = ""
    @State private var synced = false

    private var auto: Double? { session.autoPace }
    // The editable box always holds a plain decimal in the native unit; the
    // caption renders the readable form (mm:ss for min-based paces).
    private func dec(_ v: Double) -> String { trimNum((v * 10).rounded() / 10) }
    private func readable(_ v: Double) -> String {
        session.paceIsSpeed ? "\(dec(v)) \(session.paceUnit)" : "\(paceStr(v)) \(session.paceUnit)"
    }
    private var shownPace: Double? { pf(text) > 0 ? pf(text) : auto }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("\(t(session.paceIsSpeed ? "wk.speed" : "wk.pace")) (\(session.paceUnit))", info: "pace")
            TextField("", text: $text,
                      prompt: Text(auto.map { dec($0) } ?? "—").foregroundColor(Theme.sub))
                .keyboardType(.decimalPad)
                .foregroundColor(Theme.txt).font(.system(size: 16, weight: .medium))
                .padding(.vertical, 13).padding(.horizontal, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.c2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
            if let shown = shownPace {
                Text("\(text.isEmpty ? t("wk.pace_auto") : t("wk.pace")) · \(readable(shown))")
                    .font(.system(size: 9)).foregroundColor(Theme.sub)
            }
        }
        .onAppear { if !synced { if let m = manual { text = dec(m) }; synced = true } }
        .onChange(of: text) { _ in
            let v = pf(text)
            manual = (text.isEmpty || v <= 0) ? nil : v
        }
    }
}

// MARK: - Inputs
struct InputField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.sub))
            .keyboardType(keyboard)
            .foregroundColor(Theme.txt)
            .font(.system(size: 16, weight: .medium))
            .padding(.vertical, 13).padding(.horizontal, 15)
            .background(Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }
}

struct SmallNumField: View {
    @Binding var text: String
    var placeholder: String = "–"
    var highlight: Bool = false
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.sub))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .foregroundColor(Theme.txt)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 66)
            .padding(.vertical, 10)
            .background(highlight ? Theme.acc.opacity(0.07) : Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(highlight ? Theme.acc : Theme.brd, lineWidth: 1))
    }
}

// MARK: - Exercise setting controls (shared by every exercise editor)
// One implementation of the bodyweight chip, the effort-mode selector and the
// per-set effort field, reused identically in the plan editor, the live workout
// and the session editor. Keeping a single source avoids the three editors
// drifting apart and shrinks the surface where a stale-index bug can hide.

/// Capsule toggle that flips an exercise between weighted and bodyweight.
struct BodyweightChip: View {
    @Binding var isBodyweight: Bool?
    var body: some View {
        let bw = isBodyweight == true
        Button {
            tap()
            isBodyweight = bw ? nil : true
        } label: {
            Text(t("wk.bodyweight")).font(.head(9, .semibold)).tracking(0.5)
                .foregroundColor(bw ? Theme.bg : Theme.sub)
                .padding(.vertical, 4).padding(.horizontal, 7)
                .background(bw ? Theme.good : Theme.c3)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The — / RIR / RPE / FAIL chooser for an exercise's per-set effort scale.
struct EffortModeSelector: View {
    @Binding var effortMode: String?
    var body: some View {
        let cur = effortMode.flatMap { EffortMode(rawValue: $0) }
        HStack(spacing: 6) {
            Text(t("wk.effort").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Spacer()
            ForEach([EffortMode?.none] + EffortMode.allCases.map { Optional($0) }, id: \.?.rawValue) { mode in
                let label = mode?.label ?? t("wk.effort.off")
                let active = cur == mode
                Button {
                    tap()
                    effortMode = mode?.rawValue
                } label: {
                    Text(label).font(.head(10, .semibold)).tracking(0.5)
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .background(active ? Theme.acc2 : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc2 : Theme.brd, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One set's effort entry: a number box for RIR/RPE, a bolt toggle for failure.
struct EffortField: View {
    let scale: EffortMode
    @Binding var value: Int?
    @ViewBuilder var body: some View {
        switch scale {
        case .rir, .rpe:
            SmallNumField(text: Binding(
                get: { value.map { "\($0)" } ?? "" },
                set: { value = Int($0) }))
                .frame(width: 48)
        case .fail:
            let isOn = value == 1
            Button {
                tap()
                value = isOn ? 0 : 1
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Theme.red.opacity(0.18) : Theme.c2)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isOn ? Theme.red.opacity(0.5) : Theme.brd, lineWidth: 1)
                    Image(systemName: isOn ? "bolt.fill" : "bolt")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isOn ? Theme.red : Theme.sub)
                }
                .frame(width: 48, height: 42)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Empty state
struct EmptyBox: View {
    let title: String
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased()).font(.head(15, .semibold)).tracking(1).foregroundColor(Theme.sub)
            Text(text).font(.system(size: 13)).foregroundColor(Theme.sub).multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 18)
    }
}

// Wrapper so a URL can drive .sheet(item:) without a retroactive conformance.
struct IdentURL: Identifiable { let id = UUID(); let url: URL }

// MARK: - Wrapping (flow) layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

struct FlexWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    init(_ data: Data, spacing: CGFloat = 6, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.spacing = spacing; self.content = content
    }
    var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(Array(data), id: \.self) { content($0) }
        }
    }
}

// MARK: - Share sheet (export)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
