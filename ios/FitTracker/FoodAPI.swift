import Foundation

// MARK: - OpenFoodFacts barcode lookup
// Free, open, no API key. Given a scanned barcode we fetch the product's name
// and per-100 g/ml nutrition and build a FoodItem (NOT saved yet — the caller
// confirms the amount and can edit before saving). Any failure (offline, not
// found, malformed) returns nil so the UI falls back to manual entry.
enum OpenFoodFacts {
    static func lookup(barcode: String, completion: @escaping (FoodItem?) -> Void) {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,nutriments,quantity")
        else { completion(nil); return }

        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        // OpenFoodFacts asks API clients to identify themselves.
        req.setValue("FitTracker/1.0 (iOS; nutrition tracker)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            let item = data.flatMap { parse($0, barcode: code) }
            DispatchQueue.main.async { completion(item) }
        }.resume()
    }

    private static func parse(_ data: Data, barcode: String) -> FoodItem? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any] else { return nil }

        let nutr = product["nutriments"] as? [String: Any] ?? [:]
        func num(_ keys: [String]) -> Double {
            for k in keys {
                if let v = nutr[k] as? Double { return v }
                if let s = nutr[k] as? String, let v = Double(s) { return v }
            }
            return 0
        }
        var kcal = num(["energy-kcal_100g", "energy-kcal"])
        if kcal == 0 {                                   // some products only list kJ
            let kj = num(["energy-kj_100g", "energy-kj", "energy_100g"])
            if kj > 0 { kcal = kj / 4.184 }
        }
        let p = num(["proteins_100g"])
        let c = num(["carbohydrates_100g"])
        let f = num(["fat_100g"])

        let rawName = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawName.isEmpty || kcal > 0 else { return nil }   // nothing usable

        func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        return FoodItem(name: rawName.isEmpty ? barcode : rawName, barcode: barcode,
                        k100: r1(kcal), p100: r1(p), c100: r1(c), f100: r1(f))
    }
}
