import SwiftUI
import VisionKit

// MARK: - Barcode scanner (VisionKit)
// A thin SwiftUI wrapper around DataScannerViewController (iOS 16+) that reports
// the first barcode string it reads, then the caller dismisses and looks the
// code up (local list first, then OpenFoodFacts). On devices/simulators without
// camera scanning support it shows a graceful message instead.

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if DataScannerViewController.isSupported {
                DataScannerRepresentable { code in
                    haptic(.success)
                    onCode(code)
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder").font(.system(size: 40)).foregroundColor(Theme.sub)
                    Text(t("food.scan_unavailable")).font(.system(size: 13)).foregroundColor(Theme.sub)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                            .foregroundColor(.white).shadow(radius: 3)
                    }
                }
                Spacer()
                Text(t("food.scan_hint")).font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white).padding(.vertical, 8).padding(.horizontal, 14)
                    .background(.black.opacity(0.5)).clipShape(Capsule())
                    .padding(.bottom, 30)
            }
            .padding(.top, 18).padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
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
