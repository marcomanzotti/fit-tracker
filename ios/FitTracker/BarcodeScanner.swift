import Foundation
import SwiftUI
import VisionKit
import AVFoundation

// MARK: - Barcode scanner (VisionKit)
// A thin SwiftUI wrapper around DataScannerViewController (iOS 16+) that reports
// the first barcode string it reads, then the caller dismisses and looks the
// code up (local list first, then OpenFoodFacts). On devices/simulators without
// camera scanning support it shows a graceful message instead.

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void
    /// Camera permission: nil while iOS is still asking.
    @State private var cameraAllowed: Bool? = BarcodeScannerSheet.currentPermission

    private static var currentPermission: Bool? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:           return true
        case .denied, .restricted:  return false
        default:                    return nil
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !DataScannerViewController.isSupported {
                message(t("food.scan_unavailable"))
            } else if cameraAllowed == false {
                // A refused camera used to leave a black screen: say why and where to fix it.
                VStack(spacing: 14) {
                    message(t("food.camera_denied"))
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Text(t("hk.open_settings")).font(.ui(14, weight: .semibold)).foregroundColor(Theme.bg)
                            .padding(.horizontal, 20).frame(minHeight: Theme.minTapTarget)
                            .background(Theme.acc).clipShape(Capsule())
                    }
                }
            } else if cameraAllowed == true {
                DataScannerRepresentable { code in
                    haptic(.success)
                    onCode(code)
                    dismiss()
                }
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.ui(28))
                            .foregroundColor(.white).shadow(radius: 3)
                            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                            .accessibilityLabel(t("a11y.close"))
                    }
                }
                Spacer()
                Text(t("food.scan_hint")).font(.ui(12, weight: .medium))
                    .foregroundColor(.white).padding(.vertical, 8).padding(.horizontal, 14)
                    .background(.black.opacity(0.5)).clipShape(Capsule())
                    .padding(.bottom, 30)
            }
            .padding(.top, 18).padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .keyboardDoneBar()
        .task {
            guard cameraAllowed == nil else { return }
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder").font(.ui(40)).foregroundColor(Theme.sub)
            Text(text).font(.ui(13)).foregroundColor(Theme.sub)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            // Product codes only: a QR code is not a food barcode.
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        try? vc.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var fired = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(added)
        }
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }
        private func handle(_ items: [RecognizedItem]) {
            guard !fired else { return }
            for case let .barcode(b) in items {
                if let code = b.payloadStringValue, !code.isEmpty {
                    fired = true
                    onCode(code)
                    return
                }
            }
        }
    }
}

// MARK: - OpenFoodFacts barcode lookup
// Free, open, no API key. Given a scanned barcode we fetch the product's name
// and per-100 g/ml nutrition and build a FoodItem (NOT saved yet — the caller
// confirms the amount and can edit before saving). The caller is told apart a
// product that is not in the database from a lookup that could not be made, so
// "no connection" is never shown as "unknown product".
enum OpenFoodFacts {
    enum Lookup: Equatable { case found(FoodItem), notFound, unreachable }

    /// Retail barcodes are 8 to 14 digits (EAN-8, UPC, EAN-13, GTIN-14).
    private static let barcodeLength = 8...14

    static func lookup(barcode: String, completion: @escaping (Lookup) -> Void) {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only digits go into the URL: a scanned QR code can hold any text.
        guard barcodeLength.contains(code.count), code.allSatisfy({ $0.isASCII && $0.isNumber }),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,nutriments,quantity")
        else { completion(.notFound); return }

        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        // OpenFoodFacts asks API clients to identify themselves.
        req.setValue("FitTracker/1.0 (iOS; nutrition tracker)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if data == nil { appLog.error("Food lookup failed: \(String(describing: error), privacy: .public)") }
            let found = outcome(status: status, data: data, barcode: code)
            DispatchQueue.main.async { completion(found) }
        }.resume()
    }

    /// A missing product (404, or an answer without one) is "not found"; any other
    /// failure is the server or the connection, never "unknown product".
    static func outcome(status: Int, data: Data?, barcode: String) -> Lookup {
        switch status {
        case 200: return data.flatMap { parse($0, barcode: barcode) }.map(Lookup.found) ?? .notFound
        case 404: return .notFound
        default:  return .unreachable
        }
    }

    enum Search { case results([FoodItem]), unreachable }

    /// Products whose name matches the text, best matches first.
    static func search(_ text: String, completion: @escaping (Search) -> Void) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        parts?.queryItems = [URLQueryItem(name: "search_terms", value: query), URLQueryItem(name: "search_simple", value: "1"),
                             URLQueryItem(name: "action", value: "process"), URLQueryItem(name: "json", value: "1"),
                             URLQueryItem(name: "page_size", value: "20"),
                             URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments")]
        guard !query.isEmpty, let url = parts?.url else { completion(.results([])); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("FitTracker/1.0 (iOS; nutrition tracker)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let result: Search
            if status == 200, let data { result = .results(parseSearch(data)) } else {
                appLog.error("Food search failed (\(status)): \(String(describing: error), privacy: .public)")
                result = .unreachable
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    static func parseSearch(_ data: Data) -> [FoodItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else { return [] }
        return products.compactMap { product in
            guard let code = product["code"] as? String,
                  var item = food(from: product, barcode: code), !(product["product_name"] as? String ?? "").isEmpty else { return nil }
            let brand = (product["brands"] as? String)?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
            item.brand = brand?.isEmpty == false ? brand : nil
            return item
        }
    }

    /// A food database is outside data: values are taken only when they are
    /// numbers a label can carry per 100 g.
    private static let maxKcal = 900.0, maxKJ = 3_800.0, maxGrams = 100.0

    static func parse(_ data: Data, barcode: String) -> FoodItem? {
        // Anything that is not the expected JSON is "no such product".
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any] else { return nil }
        return food(from: product, barcode: barcode)
    }

    private static func food(from product: [String: Any], barcode: String) -> FoodItem? {
        let nutr = product["nutriments"] as? [String: Any] ?? [:]
        func num(_ keys: [String], max: Double) -> Double? {
            for k in keys {
                let v = (nutr[k] as? Double) ?? (nutr[k] as? String).flatMap(parsedNumber)
                if let v, v.isFinite, (0...max).contains(v) { return v }
            }
            return nil
        }
        var kcal = num(["energy-kcal_100g", "energy-kcal"], max: maxKcal) ?? 0
        if kcal == 0, let kj = num(["energy-kj_100g", "energy-kj", "energy_100g"], max: maxKJ) {
            kcal = kj / 4.184                            // some products only list kJ
        }
        // Salt is sodium × 2.5 when only sodium is on the label.
        let salt = num(["salt_100g"], max: maxGrams) ?? num(["sodium_100g"], max: maxGrams / 2.5).map { $0 * 2.5 }

        let rawName = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawName.isEmpty || kcal > 0 else { return nil }   // nothing usable

        func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
        return FoodItem(name: rawName.isEmpty ? barcode : rawName, barcode: barcode,
                        k100: r1(kcal), p100: r1(num(["proteins_100g"], max: maxGrams) ?? 0),
                        c100: r1(num(["carbohydrates_100g"], max: maxGrams) ?? 0),
                        f100: r1(num(["fat_100g"], max: maxGrams) ?? 0),
                        fiber100: num(["fiber_100g"], max: maxGrams).map(r1), salt100: salt.map { ($0 * 100).rounded() / 100 })
    }
}
