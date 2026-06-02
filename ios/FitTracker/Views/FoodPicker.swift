import SwiftUI

// MARK: - Food logging UI
// The reusable pieces that let the user log food-by-food anywhere (inside a meal
// or at the day level), always with the option to load from the local saved
// list, create a new food, or scan a barcode (OpenFoodFacts + manual fallback).

// A list of logged foods with a running total and an "add food" button. Bound to
// a [FoodLog]; used both for a meal and for the day-level food list.
struct FoodLogSection: View {
    @Binding var logs: [FoodLog]
    var accent: Color = Theme.acc
    @State private var picking = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(logs) { log in
                FoodLogRow(log: log) { delete(log) }
            }
            GhostButton(title: t("food.add"), color: accent) { picking = true }
                .frame(maxWidth: .infinity)
            if !logs.isEmpty {
                HStack {
                    Text(t("nut.day_total").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                    Spacer()
                    Text("\(logs.reduce(0) { $0 + $1.kcal }) kcal").font(.num(15)).foregroundColor(accent)
                }
                .padding(.top, 2)
            }
        }
        .sheet(isPresented: $picking) {
            FoodPickerSheet { log in logs.append(log) }
        }
    }

    private func delete(_ log: FoodLog) { logs.removeAll { $0.id == log.id } }
}

// One logged food: name + amount on the left, scaled kcal + delete on the right.
struct FoodLogRow: View {
    let log: FoodLog
    var onDelete: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt)
                    .lineLimit(1)
                Text("\(trimNum(log.grams)) g · P \(trimNum(log.protein)) C \(trimNum(log.carbs)) F \(trimNum(log.fat))")
                    .font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
            Text("\(log.kcal)").font(.num(15)).foregroundColor(Theme.acc)
            Text("kcal").font(.system(size: 9)).foregroundColor(Theme.sub)
            Button { tap(); onDelete() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundColor(Theme.mut)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 11)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Picker: choose a saved food, scan, or create a new one
private enum FoodSheet: Identifiable {
    case scan
    case form(FoodItem)
    case qty(FoodItem)
    var id: String {
        switch self {
        case .scan: return "scan"
        case .form(let f): return "form-\(f.id)"
        case .qty(let f): return "qty-\(f.id)"
        }
    }
}

private enum FoodSortKey: String, CaseIterable {
    case recent, alpha, kcal, ratio
    var label: String {
        switch self {
        case .recent: return t("food.sort.recent")
        case .alpha:  return t("food.sort.alpha")
        case .kcal:   return t("food.sort.kcal")
        case .ratio:  return t("food.sort.ratio")
        }
    }
}

struct FoodPickerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onPick: (FoodLog) -> Void

    @State private var search = ""
    @State private var sheet: FoodSheet?
    @State private var looking = false
    @State private var sortKey: FoodSortKey = .recent
    @State private var sortAsc = false

    private var filtered: [FoodItem] {
        var all = store.recentFoods()
        if !search.isEmpty { all = all.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        switch sortKey {
        case .recent:
            // recentFoods() already sorts by lastUsed desc, flip for asc
            if sortAsc { all = all.reversed() }
        case .alpha:
            all.sort { a, b in
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return sortAsc ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        case .kcal:
            all.sort { sortAsc ? $0.k100 < $1.k100 : $0.k100 > $1.k100 }
        case .ratio:
            // kcal-to-protein ratio (lower = more protein per kcal)
            let ratio = { (f: FoodItem) -> Double in f.p100 > 0 ? f.k100 / f.p100 : Double.infinity }
            all.sort { sortAsc ? ratio($0) < ratio($1) : ratio($0) > ratio($1) }
        }
        return all
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                HStack(spacing: 9) {
                    FilledButton(title: t("food.scan"), color: Theme.blue) { sheet = .scan }
                    FilledButton(title: t("food.new")) { sheet = .form(FoodItem(name: "")) }
                }
                InputField(placeholder: t("food.search"), text: $search, keyboard: .default)
                sortBar
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filtered.isEmpty {
                            Text(t("food.none")).font(.system(size: 12)).foregroundColor(Theme.sub)
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        }
                        ForEach(filtered) { f in foodRow(f) }
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 18)

            if looking {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView().tint(Theme.acc)
                    Text(t("food.looking")).font(.system(size: 12)).foregroundColor(Theme.txt)
                }
                .padding(22).background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { which in
            switch which {
            case .scan:
                BarcodeScannerSheet { code in handleScan(code) }
            case .form(let f):
                FoodFormSheet(food: f) { saved in
                    let s = store.saveFood(saved)
                    sheet = .qty(s)
                }
            case .qty(let f):
                FoodQuantitySheet(food: f) { log in
                    onPick(log)
                    dismiss()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(t("food.title")).font(.head(18, .bold)).foregroundColor(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(t("food.sort").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                ForEach(FoodSortKey.allCases, id: \.self) { key in
                    let active = sortKey == key
                    Button {
                        tap()
                        if sortKey == key { sortAsc.toggle() } else { sortKey = key; sortAsc = false }
                    } label: {
                        HStack(spacing: 3) {
                            Text(key.label).font(.head(10, .semibold)).tracking(0.5)
                            if active {
                                Image(systemName: sortAsc ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundColor(active ? Theme.bg : Theme.sub)
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .background(active ? Theme.acc : Theme.c2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? Theme.acc : Theme.brd, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func foodRow(_ f: FoodItem) -> some View {
        HStack(spacing: 10) {
            Button { tap(); sheet = .qty(f) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    Text("\(trimNum(f.k100)) kcal · P \(trimNum(f.p100)) C \(trimNum(f.c100)) F \(trimNum(f.f100)) · /100\(f.unit)")
                        .font(.system(size: 10)).foregroundColor(Theme.sub).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button { tap(); sheet = .form(f) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundColor(Theme.sub).frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(Theme.c1)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }

    private func handleScan(_ code: String) {
        if let existing = store.food(barcode: code) { sheet = .qty(existing); return }
        looking = true
        OpenFoodFacts.lookup(barcode: code) { item in
            looking = false
            sheet = .form(item ?? FoodItem(name: "", barcode: code))
        }
    }
}

// MARK: - Create / edit a saved food (per-100 macros)
struct FoodFormSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    var onSave: (FoodItem) -> Void

    @State private var name = ""
    @State private var k = ""; @State private var p = ""; @State private var c = ""; @State private var f = ""
    @State private var liquid = false
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(t("food.new_title")).font(.head(16, .bold)).foregroundColor(Theme.txt)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                        }
                    }
                    .padding(.top, 18)

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 7) {
                                FieldLabel(t("food.name"))
                                InputField(placeholder: "Riso / Rice", text: $name, keyboard: .default)
                            }
                            Text("\(t("food.per100_label")) (100\(liquid ? "ml" : "g"))".uppercased())
                                .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.acc2)
                            HStack(spacing: 10) {
                                num("KCAL", "350", $k)
                                num("\(t("nut.protein")) (g)", "7", $p)
                            }
                            HStack(spacing: 10) {
                                num("\(t("nut.carbs")) (g)", "78", $c)
                                num("\(t("nut.fat")) (g)", "1", $f)
                            }
                            Toggle(isOn: $liquid) {
                                Text(t("food.liquid")).font(.system(size: 13)).foregroundColor(Theme.txt)
                            }.tint(Theme.acc)
                        }
                    }

                    BigButton(title: t("food.save_food")) { save() }
                    if !food.name.isEmpty {
                        Button { tap(); store.deleteFood(food.id); dismiss() } label: {
                            Text(t("delete")).font(.head(13, .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = food.name
            if food.k100 > 0 { k = trimNum(food.k100) }
            if food.p100 > 0 { p = trimNum(food.p100) }
            if food.c100 > 0 { c = trimNum(food.c100) }
            if food.f100 > 0 { f = trimNum(food.f100) }
            liquid = food.liquid
        }
    }

    private func num(_ label: String, _ ph: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label)
            InputField(placeholder: ph, text: b)
        }
    }

    private func save() {
        let nm = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nm.isEmpty else { return }
        var item = food
        item.name = nm
        item.k100 = pf(k); item.p100 = pf(p); item.c100 = pf(c); item.f100 = pf(f)
        item.liquid = liquid
        item.lastUsed = today()
        haptic(.success)
        onSave(item)
        dismiss()
    }
}

// MARK: - Enter the amount eaten of a chosen food → FoodLog
struct FoodQuantitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    var onAdd: (FoodLog) -> Void

    @State private var amount = "100"

    private var grams: Double { max(0, pf(amount)) }
    private var log: FoodLog { food.log(grams) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(food.name).font(.head(17, .bold)).foregroundColor(Theme.txt).lineLimit(2)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                    }
                }
                .padding(.top, 18)

                Card {
                    VStack(alignment: .leading, spacing: 7) {
                        FieldLabel("\(t("food.amount")) (\(food.unit))")
                        InputField(placeholder: "120", text: $amount)
                    }
                }

                // Live scaled preview.
                Card(accent: Theme.acc) {
                    HStack {
                        macro("\(log.kcal)", "kcal", Theme.acc)
                        macro(trimNum(log.protein), "P", Theme.blue)
                        macro(trimNum(log.carbs), "C", Theme.acc2)
                        macro(trimNum(log.fat), "F", Theme.good)
                    }
                }

                BigButton(title: t("food.add")) {
                    guard grams > 0 else { return }
                    haptic(.success); onAdd(log); dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
    }

    private func macro(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.num(20)).foregroundColor(color)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
