import Foundation
import StoreKit

class InAppPurchaseManager: NSObject, ObservableObject {
    static let shared = InAppPurchaseManager()
    
    @Published var products: [SKProduct] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var isPurchasing = false
    
    // Product IDs for your donation amounts
    // You'll need to create these in App Store Connect
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
    
    private var productsRequest: SKProductsRequest?
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        loadProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - Product Loading
    
    func loadProducts() {
        isLoading = true
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    // MARK: - Purchase Methods
    
    func purchase(product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            purchaseError = "In-app purchases are not available on this device"
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func purchaseDonation(amount: Double) {
        // Find the product that matches the donation amount
        let productId = productIdForAmount(amount)
        if let product = products.first(where: { $0.productIdentifier == productId }) {
            purchase(product: product)
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
    
    // MARK: - Restore Purchases
    
    func restorePurchases() {
        isLoading = true
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - Helper Methods
    
    func getProductForAmount(_ amount: Double) -> SKProduct? {
        let productId = productIdForAmount(amount)
        return products.first { $0.productIdentifier == productId }
    }
    
    func formatPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "$0.00"
    }
}

// MARK: - SKProductsRequestDelegate

extension InAppPurchaseManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
            self.isLoading = false
            
            if !response.invalidProductIdentifiers.isEmpty {
                print("Invalid product identifiers: \(response.invalidProductIdentifiers)")
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }
}

// MARK: - SKPaymentTransactionObserver

extension InAppPurchaseManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handleSuccessfulPurchase(transaction)
            case .failed:
                handleFailedPurchase(transaction)
            case .restored:
                handleRestoredPurchase(transaction)
            case .deferred:
                // Transaction is waiting for approval (e.g., Ask to Buy)
                break
            case .purchasing:
                // Transaction is being processed
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handleSuccessfulPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            
            // Here you could send the transaction receipt to your server
            // for validation and to track donations
            
            // For now, we'll just show success
            print("Purchase successful: \(transaction.payment.productIdentifier)")
            
            // Finish the transaction
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
    
    private func handleFailedPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            
            if let error = transaction.error as? SKError {
                switch error.code {
                case .paymentCancelled:
                    // User cancelled - don't show error
                    break
                case .paymentNotAllowed:
                    self.purchaseError = "Payment not allowed on this device"
                case .paymentInvalid:
                    self.purchaseError = "Invalid payment"
                case .clientInvalid:
                    self.purchaseError = "Client invalid"
                case .storeProductNotAvailable:
                    self.purchaseError = "Product not available"
                default:
                    self.purchaseError = "Purchase failed: \(error.localizedDescription)"
                }
            } else {
                self.purchaseError = "Purchase failed: \(transaction.error?.localizedDescription ?? "Unknown error")"
            }
            
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
    
    private func handleRestoredPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isLoading = false
            print("Purchase restored: \(transaction.payment.productIdentifier)")
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async {
            self.isLoading = false
            print("Restore completed")
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }
}
