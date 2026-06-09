import SwiftUI
import Charts

// MARK: - Nutrition calendar (daily intake history)
// Mirrors the workout CalendarCard but colours each day by logged calories vs.
// the daily target (green ≈ on target, amber = under, red = over). Tapping ANY
// day — past or today — opens the editor so that day's nutrition can be added
// or changed. Future days are disabled.
struct NutritionCalendarCard: View {
    @EnvironmentObject var store: Store
    @State private var monthOffset = 0
    @State private var editDate: IdentDate?

    var body: some View {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: monthOffset, to: Date())!
        let comps = cal.dateComponents([.year, .month], from: base)
        let firstOfMonth = cal.date(from: comps)!
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7   // Monday=0
        let target = store.energyTargets().target

        return Card {
            HStack {
                Button { tap(); monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").foregroundColor(Theme.sub).frame(width: 30, height: 30)
                }
                Spacer()
                Text("\(L.months[comps.month! - 1]) \(comps.year!)".uppercased())
                    .font(.head(13, .semibold)).tracking(1).foregroundColor(Theme.txt)
                Spacer()
                Button { tap(); if monthOffset < 0 { monthOffset += 1 } } label: {
                    Image(systemName: "chevron.right").foregroundColor(monthOffset < 0 ? Theme.sub : Theme.mut).frame(width: 30, height: 30)
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(Array(L.weekHeaders.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.head(9, .semibold)).foregroundColor(Theme.sub).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            let cells = firstWeekday + daysInMonth
            let rows = Int(ceil(Double(cells) / 7.0))
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            let day = idx - firstWeekday + 1
                            if day >= 1 && day <= daysInMonth {
                                dayCell(day: day, firstOfMonth: firstOfMonth, target: target)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 40)
                            }
                        }
                    }
                }
            }
            Text(t("nut.cal_hint_tap")).font(.system(size: 11)).foregroundColor(Theme.sub)
                .frame(maxWidth: .infinity).padding(.top, 10)
        }
        .sheet(item: $editDate) { d in NutritionDayEditor(date: d.date) }
    }

    /// Green when within ±~12% of target, amber under, red over.
    private func dayColor(_ kcal: Int, _ target: Double) -> Color {
        guard target > 0 else { return Theme.acc2 }
        let r = Double(kcal) / target
        if r < 0.85 { return Theme.acc2 }
        if r > 1.12 { return Theme.red }
        return Theme.good
    }

    private func dayCell(day: Int, firstOfMonth: Date, target: Double) -> some View {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
        let ds = isoFormatter.string(from: date)
        let entry = store.dailyEntry(ds)
        let kcal = entry?.totalKcal ?? 0
        let logged = (entry?.hasNutrition ?? false) && kcal > 0
        let color = logged ? dayColor(kcal, target) : nil
        let isToday = ds == today()
        let future = ds > today()
        return Button {
            tap(); if !future { editDate = IdentDate(date: ds) }
        } label: {
            VStack(spacing: 1) {
                Text("\(day)").font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundColor(color != nil ? Theme.bg : (isToday ? Theme.acc : Theme.txt))
                if logged {
                    Text("\(kcal)").font(.system(size: 7, weight: .bold)).foregroundColor(Theme.bg)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(color ?? Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isToday && color == nil ? Theme.acc : Color.clear, lineWidth: 1))
            .opacity(future ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(future)
    }
}

// MARK: - Nutrition day editor (quick total OR per-meal)
// Two modes, exactly as requested: a one-tap daily total, or a per-meal
// breakdown (breakfast/lunch/dinner/snacks) that sums automatically to the day
// total. Opens for any date and always allows editing what's already there.
struct NutritionDayEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss
    let date: String

    @State private var mode = "quick"
    // Quick-total inputs
    @State private var qK = ""; @State private var qP = ""; @State private var qC = ""; @State private var qF = ""
    // Per-meal inputs: [slot raw : [field("k"/"p"/"c"/"f") : value]]
    @State private var meal: [String: [String: String]] = [:]
    // Foods logged per meal, and at the day level (food-by-food mode).
    @State private var mealFoods: [String: [FoodLog]] = [:]
    @State private var dayFoods: [FoodLog] = []
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Card {
                        FieldRow(label: t("nut.entry_mode")) {
                            PillSelect(options: ["quick", "per_meal", "foods"],
                                       title: { $0 == "quick" ? t("nut.quick") : ($0 == "per_meal" ? t("nut.per_meal") : t("nut.foods")) },
                                       selection: $mode)
                        }
                    }
                    if mode == "quick" { quickCard }
                    else if mode == "per_meal" { perMealCard }
                    else { foodsCard }
                    BigButton(title: t("save")) { saveAction() }
                    Button { tap(); store.saveNutritionTotal(date: date, kcal: nil, protein: nil, carbs: nil, fat: nil); store.saveDayFoods(date: date, foods: []); toast.show(t("nut.cleared")); dismiss() } label: {
                        Text(t("delete")).font(.head(13, .semibold)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear { if !loaded { load(); loaded = true } }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("nut.edit_day").uppercased()).font(.head(16, .bold)).tracking(1).foregroundColor(Theme.txt)
                Text(prettyDate).font(.system(size: 11)).foregroundColor(Theme.sub)
            }
            Spacer()
            Button { tap(); dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    // MARK: Quick total
    private var quickCard: some View {
        Card {
            Lbl(text: t("nut.day_total"), color: Theme.acc2).padding(.bottom, 10)
            HStack(spacing: 10) {
                labeled("KCAL", "2400", $qK, .numberPad)
                labeled("\(t("nut.protein")) (g)", "180", $qP)
            }.padding(.bottom, 10)
            HStack(spacing: 10) {
                labeled("\(t("nut.carbs")) (g)", "250", $qC)
                labeled("\(t("nut.fat")) (g)", "70", $qF)
            }
        }
    }

    // MARK: Per-meal
    private var perMealCard: some View {
        VStack(spacing: 11) {
            ForEach(MealSlot.allCases) { slot in mealCard(slot) }
            Card(accent: Theme.acc) {
                HStack {
                    Lbl(text: t("nut.day_total"), color: Theme.acc2)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(mealTotalKcal)").font(.num(26)).foregroundColor(Theme.acc)
                        Text("kcal").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.sub)
                    }
                }
            }
        }
    }

    private func mealCard(_ slot: MealSlot) -> some View {
        let hasFoods = !(mealFoods[slot.rawValue]?.isEmpty ?? true)
        return Card {
            HStack(spacing: 8) {
                Image(systemName: slot.icon).font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: slot.color))
                Text(t(slot.labelKey)).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
                Spacer()
            }
            .padding(.bottom, 10)
            // Food-by-food for this meal (load saved / new / scan). When foods are
            // present they drive the meal total and the manual fields are hidden.
            FoodLogSection(logs: mealFoodsBinding(slot.rawValue), accent: Color(hex: slot.color))
            if !hasFoods {
                Spacer().frame(height: 10)
                HStack(spacing: 10) {
                    labeled("KCAL", "600", bind(slot.rawValue, "k"), .numberPad)
                    labeled("\(t("nut.protein")) (g)", "40", bind(slot.rawValue, "p"))
                }.padding(.bottom, 10)
                HStack(spacing: 10) {
                    labeled("\(t("nut.carbs")) (g)", "60", bind(slot.rawValue, "c"))
                    labeled("\(t("nut.fat")) (g)", "20", bind(slot.rawValue, "f"))
                }
            }
        }
    }

    // MARK: Day-level food-by-food
    private var foodsCard: some View {
        VStack(spacing: 11) {
            Card {
                Lbl(text: t("food.day_foods"), color: Theme.acc2).padding(.bottom, 10)
                FoodLogSection(logs: $dayFoods)
            }
        }
    }

    private func mealFoodsBinding(_ slot: String) -> Binding<[FoodLog]> {
        Binding(get: { mealFoods[slot] ?? [] }, set: { mealFoods[slot] = $0 })
    }

    private func labeled(_ label: String, _ ph: String, _ binding: Binding<String>, _ kb: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.head(10, .semibold)).tracking(1).foregroundColor(Theme.sub)
            InputField(placeholder: ph, text: binding, keyboard: kb)
        }
    }

    private func bind(_ slot: String, _ field: String) -> Binding<String> {
        Binding(get: { meal[slot]?[field] ?? "" },
                set: { var d = meal[slot] ?? [:]; d[field] = $0; meal[slot] = d })
    }

    private var mealTotalKcal: Int {
        MealSlot.allCases.reduce(0) { sum, s in
            let foods = mealFoods[s.rawValue] ?? []
            if !foods.isEmpty { return sum + foods.reduce(0) { $0 + $1.kcal } }
            return sum + (Int(meal[s.rawValue]?["k"] ?? "") ?? 0)
        }
    }

    private func load() {
        let e = store.dailyEntry(date)
        if let df = e?.foods, !df.isEmpty {
            mode = "foods"
            dayFoods = df
        } else if let meals = e?.meals, !meals.isEmpty {
            mode = "per_meal"
            for (k, v) in meals {
                if let foods = v.foods, !foods.isEmpty { mealFoods[k] = foods }
                meal[k] = ["k": v.kcal > 0 ? String(v.kcal) : "",
                           "p": v.protein > 0 ? trimNum(v.protein) : "",
                           "c": v.carbs > 0 ? trimNum(v.carbs) : "",
                           "f": v.fat > 0 ? trimNum(v.fat) : ""]
            }
        } else if (e?.kcal ?? 0) > 0 {
            mode = "quick"
            qK = e?.kcal.map(String.init) ?? ""
            qP = e?.protein.map { trimNum($0) } ?? ""
            qC = e?.carbs.map { trimNum($0) } ?? ""
            qF = e?.fat.map { trimNum($0) } ?? ""
        } else {
            // Nothing logged yet: default to per_meal for today, quick for past days.
            mode = (date == today()) ? "per_meal" : "quick"
        }
    }

    private func saveAction() {
        switch mode {
        case "quick":
            store.saveNutritionTotal(date: date,
                                     kcal: Int(qK), protein: dn(qP), carbs: dn(qC), fat: dn(qF))
            store.saveDayFoods(date: date, foods: [])      // ensure day foods cleared
        case "foods":
            store.saveDayFoods(date: date, foods: dayFoods)
        default:                                            // per_meal
            var meals: [String: MealEntry] = [:]
            for s in MealSlot.allCases {
                let foods = mealFoods[s.rawValue] ?? []
                var m: MealEntry
                if !foods.isEmpty {
                    m = MealEntry(foods: foods)             // foods drive the total
                } else {
                    m = MealEntry(kcal: Int(meal[s.rawValue]?["k"] ?? "") ?? 0,
                                  protein: pf(meal[s.rawValue]?["p"] ?? ""),
                                  carbs: pf(meal[s.rawValue]?["c"] ?? ""),
                                  fat: pf(meal[s.rawValue]?["f"] ?? ""))
                }
                if !m.isEmpty { meals[s.rawValue] = m }
            }
            store.saveNutritionMeals(date: date, meals: meals)
            store.saveDayFoods(date: date, foods: [])      // clear any day-level foods
        }
        haptic(.success); toast.show(t("nut.saved")); dismiss()
    }

    private func dn(_ s: String) -> Double? { s.isEmpty ? nil : pf(s) }

    private var prettyDate: String {
        guard let d = isoFormatter.date(from: date) else { return date }
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "en" ? "en_US" : "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d).capitalized
    }
}

// MARK: - Nutrition charts (calories + macros, same style as other metrics)
struct NutritionChartsSection: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let s = store.nutritionSeries(days: 90)
        let target = store.energyTargets()
        return Group {
            if s.count < 2 {
                Card { EmptyBox(title: t("nut.no_log"), text: t("nut.charts_hint")) }
            } else {
                macroChart(t("nut.kcal"), s.map { ($0.date, Double($0.kcal)) }, Theme.acc, target: target.target)
                macroChart("\(t("nut.protein")) (g)", s.map { ($0.date, $0.protein) }, Theme.blue, target: target.protein)
                macroChart("\(t("nut.carbs")) (g)", s.map { ($0.date, $0.carbs) }, Theme.acc2, target: target.carbs)
                macroChart("\(t("nut.fat")) (g)", s.map { ($0.date, $0.fat) }, Theme.good, target: target.fat)
            }
        }
    }

    private func macroChart(_ title: String, _ pts: [(String, Double)], _ color: Color, target: Double?) -> some View {
        Card {
            Lbl(text: title).padding(.bottom, 8)
            Chart {
                ForEach(pts, id: \.0) { p in
                    LineMark(x: .value("g", fmtShort(p.0)), y: .value("v", p.1))
                        .interpolationMethod(.catmullRom).foregroundStyle(color)
                    AreaMark(x: .value("g", fmtShort(p.0)), y: .value("v", p.1))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                }
                if let target, target > 0 {
                    RuleMark(y: .value("t", target))
                        .foregroundStyle(Theme.sub.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false)).styledAxes().frame(height: 140)
        }
    }
}

// MARK: - Small section header (Workout / Nutrition split in Stats history)
struct SectionHeader: View {
    let text: String
    var icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.acc)
            Text(text.uppercased()).font(.head(13, .bold)).tracking(1.5).foregroundColor(Theme.txt)
            Spacer()
        }
        .padding(.top, 4)
    }
}
