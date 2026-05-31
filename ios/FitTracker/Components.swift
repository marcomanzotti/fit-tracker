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

// MARK: - Small stat tile
struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var valueColor: Color = Theme.txt
    var note: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Lbl(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.num(30)).foregroundColor(valueColor)
                if let unit { Text(unit).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub) }
            }
            if let note { Text(note).font(.system(size: 10)).foregroundColor(Theme.sub) }
        }
        .padding(.vertical, 13).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
