import SwiftUI

enum Tab: String, CaseIterable {
    case home, allena, corpo, stats
    var label: String {
        switch self {
        case .home: return "Home"; case .allena: return "Allena"
        case .corpo: return "Corpo"; case .stats: return "Stats"
        }
    }
    var sub: String {
        switch self {
        case .home: return "Dashboard"; case .allena: return "Log allenamento"
        case .corpo: return "Misurazioni & Check-in"; case .stats: return "Statistiche"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var timer: RestTimer
    @EnvironmentObject var toast: ToastCenter
    @State private var tab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(tab: tab)
                ScrollView {
                    VStack(spacing: 11) {
                        switch tab {
                        case .home:   HomeView(tab: $tab)
                        case .allena: WorkoutView()
                        case .corpo:  BodyView()
                        case .stats:  StatsView()
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 130)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            VStack(spacing: 8) {
                if timer.active { TimerStrip() }
                NavBar(tab: $tab)
            }
        }
        .overlay(alignment: .top) {
            if let m = toast.message {
                ToastView(text: m)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast.message)
    }
}

// MARK: - Header
struct HeaderBar: View {
    @EnvironmentObject var store: Store
    let tab: Tab
    var body: some View {
        let d = headerDate()
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("FIT TR").foregroundColor(Theme.txt)
                    Text("A").foregroundColor(Theme.acc)
                    Text("CKER").foregroundColor(Theme.txt)
                }
                .font(.head(23, .bold)).tracking(1)
                Text(tab.sub.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.5)
                    .foregroundColor(Theme.sub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(d.full).font(.num(16)).foregroundColor(Theme.txt)
                Text(d.day.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundColor(Theme.sub)
                Text("\(trimNum(store.lastWeight)) kg").font(.num(15)).foregroundColor(Theme.acc)
            }
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
        .background(Theme.bg.opacity(0.92))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.brd).frame(height: 1) }
    }
}

// MARK: - Bottom navigation
struct NavBar: View {
    @Binding var tab: Tab
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    tap(); tab = t
                } label: {
                    VStack(spacing: 6) {
                        Circle().fill(t == tab ? Theme.acc : .clear).frame(width: 5, height: 5)
                        Text(t.label.uppercased()).font(.head(11, .semibold)).tracking(1.5)
                            .foregroundColor(t == tab ? Theme.acc : Theme.sub)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.bottom, 8)
        .background(Theme.c1.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(Theme.brd).frame(height: 1) }
    }
}

// MARK: - Rest timer strip
struct TimerStrip: View {
    @EnvironmentObject var timer: RestTimer
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RECUPERO").font(.head(9, .semibold)).tracking(2).foregroundColor(Theme.sub)
                if timer.done {
                    Text("VAI").font(.head(13, .bold)).tracking(0.5).foregroundColor(Theme.acc)
                } else {
                    Text(timer.label).font(.num(32)).foregroundColor(Theme.acc)
                        .frame(minWidth: 56, alignment: .leading)
                }
            }
            Bar(value: timer.progress, height: 5).frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Button { tap(); timer.reset() } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
                Button { tap(); timer.stop() } label: {
                    Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 17)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.brd2, lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
