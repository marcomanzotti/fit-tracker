import SwiftUI

// MARK: - Nutrition page (dedicated tab)
// Consolidates everything food-related that used to be scattered around the app:
// today's intake logging (quick / per-meal / food-by-food with barcode scan via
// NutritionDayEditor), a managed food database, the daily targets, and the
// calorie/macro charts. The Home dashboard's NutritionCard is intentionally left
// untouched; the day-by-day history calendar stays in Stats → History.
struct NutritionView: View {
    @EnvironmentObject var store: Store

    @State private var editingToday = false

    var body: some View {
        targetCard
        todayCard
        FoodDatabaseCard()
        NutritionChartsSection()
    }

    // MARK: Today's targets (compact, action-oriented header)
    private var targetCard: some View {
        let e = store.energyTargets()
        return Card(accent: Theme.acc) {
            HStack(spacing: 6) {
                Lbl(text: t("nut.target"), color: Theme.acc2)
                InfoButton(id: "tdee", color: Theme.acc2)
                Spacer()
                Text(modeLabel(e.mode).uppercased()).font(.head(11, .semibold)).tracking(1).foregroundColor(Theme.acc)
            }
            .padding(.bottom, 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(e.target))").font(.num(34)).foregroundColor(Theme.txt)
                Text("kcal").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                Text("TDEE \(Int(e.tdee)) · BMR \(Int(e.bmr))").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 12)
            HStack(spacing: 9) {
                StatTile(label: t("nut.protein"), value: "\(Int(e.protein))", unit: "g", valueColor: Theme.blue, info: "macros")
                StatTile(label: t("nut.carbs"), value: "\(Int(e.carbs))", unit: "g", valueColor: Theme.acc2, info: "macros")
                StatTile(label: t("nut.fat"), value: "\(Int(e.fat))", unit: "g", valueColor: Theme.good, info: "macros")
            }
        }
    }

    // MARK: Today's intake (logged vs target + the main logging entry point)
    private var todayCard: some View {
        let e = store.energyTargets()
        let entry = store.dailyEntry(today())
        let kcal = entry?.totalKcal ?? 0
        let logged = (entry?.hasNutrition ?? false) && kcal > 0
        let pct = e.target > 0 ? Double(kcal) / e.target : 0
        return Card {
            Lbl(text: "\(t("nutp.today")) · \(today())", color: Theme.acc2).padding(.bottom, 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(kcal)").font(.num(30)).foregroundColor(logged ? Theme.acc : Theme.sub)
                Text("/ \(Int(e.target)) kcal").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.sub)
                Spacer()
                if logged {
                    Text("P \(Int(entry?.totalProtein ?? 0)) · C \(Int(entry?.totalCarbs ?? 0)) · F \(Int(entry?.totalFat ?? 0)) g")
                        .font(.system(size: 10)).foregroundColor(Theme.sub)
                }
            }
            .padding(.bottom, 8)
            Bar(value: min(1, pct), gradient: pct > 1.12 ? [Theme.red, Theme.red] : [Theme.acc, Theme.acc2])
                .padding(.bottom, 14)
            FilledButton(title: logged ? t("nutp.edit_today") : t("nutp.log_today")) { editingToday = true }
        }
        .sheet(isPresented: $editingToday) { NutritionDayEditor(date: today()) }
    }

    private func modeLabel(_ m: GoalMode) -> String {
        switch m { case .cut: return t("nut.cut"); case .bulk: return t("nut.bulk"); default: return t("nut.maintain") }
    }
}

// MARK: - Food database management
// The saved-food list, editable independently of any single day. Lets the user
// curate their foods (create, edit per-100 macros, delete) and pre-fill new ones
// by scanning a barcode (OpenFoodFacts), so logging later is one tap.
private enum DBSheet: Identifiable {
    case scan
    case form(FoodItem)
    var id: String {
        switch self {
        case .scan: return "scan"
        case .form(let f): return "form-\(f.id)"
        }
    }
}

struct FoodDatabaseCard: View {
    @EnvironmentObject var store: Store
    @State private var sheet: DBSheet?
    @State private var looking = false

    var body: some View {
        let foods = store.recentFoods()
        return Card {
            HStack {
                Lbl(text: t("nutp.my_foods"), color: Theme.acc2)
                Spacer()
                Text("\(foods.count)").font(.num(13)).foregroundColor(Theme.sub)
            }
            .padding(.bottom, 10)
            HStack(spacing: 9) {
                FilledButton(title: t("food.scan"), color: Theme.blue) { sheet = .scan }
                FilledButton(title: t("food.new")) { sheet = .form(FoodItem(name: "")) }
            }
            .padding(.bottom, foods.isEmpty ? 0 : 10)
            if foods.isEmpty {
                Text(t("nutp.no_foods")).font(.system(size: 11)).foregroundColor(Theme.sub)
                    .frame(maxWidth: .infinity).padding(.top, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(foods.prefix(12)) { f in foodRow(f) }
                }
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .scan:
                BarcodeScannerSheet { code in handleScan(code) }
            case .form(let f):
                FoodFormSheet(food: f) { saved in _ = store.saveFood(saved) }
            }
        }
        .overlay {
            if looking {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView().tint(Theme.acc)
                        Text(t("food.looking")).font(.system(size: 12)).foregroundColor(Theme.txt)
                    }
                    .padding(22).background(Theme.c1).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func foodRow(_ f: FoodItem) -> some View {
        Button { tap(); sheet = .form(f) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    Text("\(trimNum(f.k100)) kcal · P \(trimNum(f.p100)) C \(trimNum(f.c100)) F \(trimNum(f.f100)) · /100\(f.unit)")
                        .font(.system(size: 10)).foregroundColor(Theme.sub).lineLimit(1)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundColor(Theme.sub)
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.c2)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.brd, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func handleScan(_ code: String) {
        if let existing = store.food(barcode: code) { sheet = .form(existing); return }
        looking = true
        OpenFoodFacts.lookup(barcode: code) { item in
            looking = false
            sheet = .form(item ?? FoodItem(name: "", barcode: code))
        }
    }
}
