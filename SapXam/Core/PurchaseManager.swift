import StoreKit

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published var isPro = false
    @Published var product: Product?
    @Published var isLoadingProduct = false
    @Published var productLoadFailed = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?

    private let productID = "com.quyenngo.sapxam.pro"
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await updateEntitlementStatus() }
    }

    deinit { transactionListener?.cancel() }

    func loadProduct() async {
        isLoadingProduct = true
        productLoadFailed = false
        do {
            let products = try await withTimeout(seconds: 10) {
                try await Product.products(for: [self.productID])
            }
            product = products.first
            if product == nil { productLoadFailed = true }
        } catch {
            productLoadFailed = true
        }
        isLoadingProduct = false
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            guard let result = try await group.next() else { throw CancellationError() }
            group.cancelAll()
            return result
        }
    }

    func purchase() async {
        guard let product else {
            purchaseError = "Product not available. Please try again."
            return
        }
        isPurchasing = true
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Grant on both .verified AND .unverified — treating unverified as a hard
                // failure silently drops legitimate purchases (JWS edge cases, StoreKit
                // sandbox quirks). Finish the transaction either way so it doesn't retry forever.
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    isPro = true
                case .unverified(let transaction, _):
                    await transaction.finish()
                    isPro = true
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                purchaseError = "An unexpected error occurred."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isPurchasing = false
    }

    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Could not restore purchases. Please try again."
            isPurchasing = false
            return
        }
        await updateEntitlementStatus()
        if !isPro { purchaseError = "No purchase found to restore." }
        isPurchasing = false
    }

    func updateEntitlementStatus() async {
        #if DEBUG
        // Dev convenience: auto-grant Pro in DEBUG so Hard AI is testable in the
        // Simulator without a StoreKit configuration file. BUT this must not leak
        // into the Home or Upgrade screenshots used for the App Store listing —
        // a free-tier user should see the real locked/unpurchased state there.
        // Same bug shape (and same fix) as Pallanguzhi's DEBUG isPro leak.
        let env = ProcessInfo.processInfo.environment
        let capture = env["SX_CAPTURE"]
        let isHomeCapture = capture == nil && env["SX_SKIP_ONBOARDING"] != nil
        if capture == "upgrade" || isHomeCapture {
            isPro = false
        } else {
            isPro = true
        }
        #else
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction), .unverified(let transaction, _):
                if transaction.productID == productID, transaction.revocationDate == nil {
                    isPro = true
                    return
                }
            }
        }
        isPro = false
        #endif
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction), .unverified(let transaction, _):
                    await transaction.finish()
                    await self?.updateEntitlementStatus()
                }
            }
        }
    }
}
