import Foundation
import StoreKit

@MainActor
class InAppPurchaseManager: ObservableObject {
    static let shared = InAppPurchaseManager()
    
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var isPurchasing = false
    
    // Product IDs for your donation amounts (CONSUMABLE products)
    // You'll need to create these as CONSUMABLE products in App Store Connect
    // Consumable = users can donate multiple times
    private let productIdentifiers: Set<String> = [
        "com.tvrgod.easydial.donation.0.99",
        "com.tvrgod.easydial.donation.1.99",
        "com.tvrgod.easydial.donation.2.99",
        "com.tvrgod.easydial.donation.4.99",
        "com.tvrgod.easydial.donation.9.99",
        "com.tvrgod.easydial.donation.14.99",
        "com.tvrgod.easydial.donation.19.99",
        "com.tvrgod.easydial.donation.20.00"
    ]
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        // Start listening for transaction updates
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        
        do {
            products = try await Product.products(for: productIdentifiers)
            
            // Validate that all products are consumable (required for donations)
            for product in products {
                if product.type != .consumable {
                    print("⚠️ WARNING: Product \(product.id) is not configured as CONSUMABLE in App Store Connect")
                    print("⚠️ Donation products must be CONSUMABLE to allow multiple purchases")
                }
            }
            
            isLoading = false
        } catch {
            isLoading = false
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Purchase Methods
    
    func purchase(product: Product) async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                await handleSuccessfulPurchase(verification: verification)
            case .userCancelled:
                // User cancelled - no error needed
                break
            case .pending:
                purchaseError = "Purchase is pending approval"
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    func purchaseDonation(amount: Double) async {
        let productId = productIdForAmount(amount)
        if let product = products.first(where: { $0.id == productId }) {
            await purchase(product: product)
        } else {
            purchaseError = "Donation option not available. Please try again later."
        }
    }
    
    private func productIdForAmount(_ amount: Double) -> String {
        switch amount {
        case 0.99: return "com.tvrgod.easydial.donation.0.99"
        case 1.99: return "com.tvrgod.easydial.donation.1.99"
        case 2.99: return "com.tvrgod.easydial.donation.2.99"
        case 4.99: return "com.tvrgod.easydial.donation.4.99"
        case 9.99: return "com.tvrgod.easydial.donation.9.99"
        case 14.99: return "com.tvrgod.easydial.donation.14.99"
        case 19.99: return "com.tvrgod.easydial.donation.19.99"
        case 20.00: return "com.tvrgod.easydial.donation.20.00"
        default: return "com.tvrgod.easydial.donation.2.99"
        }
    }
    
    // MARK: - Restore Purchases (Not needed for consumable donations)
    
    // Note: Consumable products don't need restore functionality
    // Users can simply purchase again if they want to donate more
    
    // MARK: - Helper Methods
    
    func getProductForAmount(_ amount: Double) -> Product? {
        let productId = productIdForAmount(amount)
        return products.first { $0.id == productId }
    }
    
    func formatPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    // MARK: - Transaction Handling
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.handleSuccessfulPurchase(verification: result)
                    await transaction.finish()
                } catch {
                    // Handle verification failure
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func handleSuccessfulPurchase(verification: VerificationResult<Transaction>) async {
        do {
            let transaction = try await checkVerified(verification)
            
            // Here you could send the transaction to your server for validation
            // For now, we'll just log success
            print("Purchase successful: \(transaction.productID)")
            
            // Finish the transaction
            await transaction.finish()
        } catch {
            print("Purchase verification failed: \(error)")
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        // Check whether the JWS passes StoreKit verification
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification
            throw PurchaseError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value
            return safe
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: Error, LocalizedError {
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed"
        }
    }
}