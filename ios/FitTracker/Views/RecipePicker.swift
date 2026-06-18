import SwiftUI

// MARK: - Recipe picker sheet (mirrors FoodPickerSheet)
// Shown when the user swipes right in the food-picker to the Recipes tab.
// Supports: search, sort (recent/alpha/kcal), create new recipe, pick + log a portion.

private enum RecipeSheet: Identifiable {
    case form(Recipe)
    case qty(Recipe)
    var id: String {
        switch self {
        case .form(let r): return "form-\(r.id)"
        case .qty(let r):  return "qty-\(r.id)"
        }
    }
}

private enum RecipeSortKey: String, CaseIterable {
    case recent, alpha, kcal
    var label: String {
        switch self {
        case .recent: return t("food.sort.recent")
        case .alpha:  return t("food.sort.alpha")
        case .kcal:   return t("food.sort.kcal")
        }
    }
}

struct RecipePickerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onPick: (FoodLog) -> Void

    @State private var search = ""
    @State private var sheet: RecipeSheet?
    @State private var sortKey: RecipeSortKey = .recent
    @State private var sortAsc = false

    private var filtered: [Recipe] {
        var all = store.recentRecipes()
        if !search.isEmpty { all = all.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        switch sortKey {
        case .recent:
            if sortAsc { all = all.reversed() }
        case .alpha:
            all.sort { a, b in
                let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
                return sortAsc ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        case .kcal:
            all.sort { sortAsc ? $0.effK100 < $1.effK100 : $0.effK100 > $1.effK100 }
        }
        return all
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                FilledButton(title: t("recipe.new")) { sheet = .form(Recipe(name: "")) }
                InputField(placeholder: t("food.search"), text: $search, keyboard: .default)
                sortBar
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filtered.isEmpty {
                            Text(t("recipe.none")).font(.system(size: 12)).foregroundColor(Theme.sub)
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        }
                        ForEach(filtered) { r in recipeRow(r) }
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { which in
            switch which {
            case .form(let r):
                RecipeFormSheet(recipe: r) { saved in
                    let s = store.saveRecipe(saved)
                    sheet = .qty(s)
                }
            case .qty(let r):
                RecipeQuantitySheet(recipe: r) { log in
                    onPick(log)
                    dismiss()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(t("recipe.title")).font(.head(18, .bold)).foregroundColor(Theme.txt)
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
                ForEach(RecipeSortKey.allCases, id: \.self) { key in
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

    private func recipeRow(_ r: Recipe) -> some View {
        HStack(spacing: 10) {
            Button { tap(); sheet = .qty(r) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                    let sub = r.perServing
                        ? "\(trimNum(r.effK100)) kcal/\(t("recipe.serving")) · P \(trimNum(r.effP100)) C \(trimNum(r.effC100)) F \(trimNum(r.effF100))"
                        : "\(trimNum(r.effK100)) kcal · P \(trimNum(r.effP100)) C \(trimNum(r.effC100)) F \(trimNum(r.effF100)) · /100g"
                    Text(sub).font(.system(size: 10)).foregroundColor(Theme.sub).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button { tap(); sheet = .form(r) } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundColor(Theme.sub).frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(Theme.c1)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.brd, lineWidth: 1))
    }
}

// MARK: - Recipe quantity / portion picker → produces a FoodLog
struct RecipeQuantitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onAdd: (FoodLog) -> Void

    @State private var amount = ""

    /// The entered amount, in the recipe's native unit (grams, or portions when
    /// perServing). `recipe.log` interprets it according to `perServing`.
    private var enteredAmount: Double { max(0, pf(amount)) }
    private var log: FoodLog { recipe.log(enteredAmount) }
    private var unit: String { recipe.perServing ? t("recipe.serving") : "g" }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(recipe.name).font(.head(17, .bold)).foregroundColor(Theme.txt).lineLimit(2)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
                    }
                }
                .padding(.top, 18)

                Card {
                    VStack(alignment: .leading, spacing: 7) {
                        FieldLabel("\(t("food.amount")) (\(unit))")
                        InputField(placeholder: recipe.perServing ? "1" : "150", text: $amount)
                    }
                }

                Card(accent: Theme.acc) {
                    HStack {
                        macro("\(log.kcal)", "kcal", Theme.acc)
                        macro(trimNum(log.protein), "P", Theme.blue)
                        macro(trimNum(log.carbs), "C", Theme.acc2)
                        macro(trimNum(log.fat), "F", Theme.good)
                    }
                }

                BigButton(title: t("food.add")) {
                    guard enteredAmount > 0 else { return }
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

// MARK: - Recipe form (create / edit)
// Two creation modes:
//   1. From scratch: enter per-100g values OR total+servings values manually.
//   2. From ingredients: add saved FoodItems with amounts; macros are computed.
struct RecipeFormSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onSave: (Recipe) -> Void

    // Basic info
    @State private var name = ""
    @State private var inputMode = "manual"   // "manual" | "ingredients"
    @State private var perServing = false
    @State private var servingsStr = "1"

    // Manual macro inputs
    @State private var k = ""; @State private var p = ""; @State private var c = ""; @State private var f = ""

    // Ingredients
    @State private var ingredients: [RecipeIngredient] = []
    @State private var pickingIngredient = false

    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    formHeader
                    nameCard
                    modeCard
                    if inputMode == "manual" { manualCard }
                    else { ingredientsCard }
                    BigButton(title: t("food.save_food")) { save() }
                    if !recipe.name.isEmpty {
                        Button { tap(); store.deleteRecipe(recipe.id); dismiss() } label: {
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
        .onAppear { loadExisting() }
        .sheet(isPresented: $pickingIngredient) {
            FoodPickerSheet { log in
                ingredients.append(RecipeIngredient(
                    foodId: log.foodId, name: log.name, grams: log.grams,
                    k100: log.k100, p100: log.p100, c100: log.c100, f100: log.f100))
            }
        }
    }

    private var formHeader: some View {
        HStack {
            Text(recipe.name.isEmpty ? t("recipe.new") : t("recipe.edit"))
                .font(.head(16, .bold)).foregroundColor(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").foregroundColor(Theme.sub).frame(width: 34, height: 34)
            }
        }
        .padding(.top, 18)
    }

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 7) {
                FieldLabel(t("food.name"))
                InputField(placeholder: t("recipe.name_placeholder"), text: $name, keyboard: .default)
                    .onChange(of: name) { v in
                        let tc = titleCased(v)
                        if tc != v { name = tc }
                    }
            }
        }
    }

    private var modeCard: some View {
        Card {
            FieldRow(label: t("recipe.input_mode")) {
                PillSelect(options: ["manual", "ingredients"],
                           title: { $0 == "manual" ? t("recipe.manual") : t("recipe.from_ingredients") },
                           selection: $inputMode)
            }
        }
    }

    // MARK: Manual macro entry (per-100g or total+servings)
    private var manualCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $perServing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("recipe.per_serving_toggle")).font(.system(size: 13)).foregroundColor(Theme.txt)
                        Text(t("recipe.per_serving_hint")).font(.system(size: 10)).foregroundColor(Theme.sub)
                    }
                }.tint(Theme.acc)

                if perServing {
                    VStack(alignment: .leading, spacing: 7) {
                        FieldLabel(t("recipe.servings"))
                        InputField(placeholder: "4", text: $servingsStr)
                    }
                    Text(t("recipe.total_macros_label").uppercased())
                        .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.acc2)
                } else {
                    Text("PER 100g".uppercased())
                        .font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.acc2)
                }

                HStack(spacing: 10) {
                    macroField("KCAL", "350", $k)
                    macroField("\(t("nut.protein")) (g)", "30", $p)
                }
                HStack(spacing: 10) {
                    macroField("\(t("nut.carbs")) (g)", "40", $c)
                    macroField("\(t("nut.fat")) (g)", "10", $f)
                }
            }
        }
    }

    // MARK: Ingredients list
    private var ingredientsCard: some View {
        VStack(spacing: 11) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Lbl(text: t("recipe.ingredients"), color: Theme.acc2)
                    if !ingredients.isEmpty {
                        ForEach(ingredients) { ing in ingredientRow(ing) }
                        Divider().background(Theme.brd).padding(.vertical, 4)
                        // Running totals
                        let totK = ingredients.reduce(0) { $0 + $1.kcal }
                        let totP = ingredients.reduce(0.0) { $0 + $1.protein }
                        let totC = ingredients.reduce(0.0) { $0 + $1.carbs }
                        let totF = ingredients.reduce(0.0) { $0 + $1.fat }
                        HStack {
                            Text(t("nut.day_total").uppercased()).font(.head(9, .semibold)).tracking(1).foregroundColor(Theme.sub)
                            Spacer()
                            Text("\(totK) kcal · P\(trimNum(totP)) C\(trimNum(totC)) F\(trimNum(totF))")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.acc)
                        }
                    }
                    GhostButton(title: "+ \(t("recipe.add_ingredient"))") { tap(); pickingIngredient = true }
                        .frame(maxWidth: .infinity)
                }
            }

            Card {
                Toggle(isOn: $perServing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("recipe.per_serving_toggle")).font(.system(size: 13)).foregroundColor(Theme.txt)
                        Text(t("recipe.per_serving_hint")).font(.system(size: 10)).foregroundColor(Theme.sub)
                    }
                }.tint(Theme.acc)
                if perServing {
                    VStack(alignment: .leading, spacing: 7) {
                        Spacer().frame(height: 4)
                        FieldLabel(t("recipe.servings"))
                        InputField(placeholder: "4", text: $servingsStr)
                    }
                }
            }
        }
    }

    private func ingredientRow(_ ing: RecipeIngredient) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ing.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.txt).lineLimit(1)
                Text("\(trimNum(ing.grams)) g · \(ing.kcal) kcal").font(.system(size: 10)).foregroundColor(Theme.sub)
            }
            Spacer()
            Button { tap(); ingredients.removeAll { $0.id == ing.id } } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundColor(Theme.mut)
            }
        }
        .padding(.vertical, 7).padding(.horizontal, 10)
        .background(Theme.c2)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func macroField(_ label: String, _ ph: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldLabel(label)
            InputField(placeholder: ph, text: b)
        }
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        name = recipe.name
        perServing = recipe.perServing
        servingsStr = recipe.servings > 0 ? trimNum(recipe.servings) : "1"
        if !recipe.ingredients.isEmpty {
            inputMode = "ingredients"
            ingredients = recipe.ingredients
        } else {
            if recipe.k100 > 0 { k = trimNum(recipe.k100) }
            if recipe.p100 > 0 { p = trimNum(recipe.p100) }
            if recipe.c100 > 0 { c = trimNum(recipe.c100) }
            if recipe.f100 > 0 { f = trimNum(recipe.f100) }
        }
    }

    private func save() {
        let nm = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nm.isEmpty else { return }
        var r = recipe
        r.name = nm
        r.perServing = perServing
        r.servings = max(1, pf(servingsStr))
        r.lastUsed = today()

        if inputMode == "ingredients" {
            r.ingredients = ingredients
            r.rebuildFromIngredients()
        } else {
            r.ingredients = []
            r.k100 = pf(k); r.p100 = pf(p); r.c100 = pf(c); r.f100 = pf(f)
        }
        haptic(.success)
        onSave(r)
        dismiss()
    }
}
