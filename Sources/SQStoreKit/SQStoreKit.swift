//
//  SQStoreKit.swift
//  SQStoreKit
//
//  Created by Виталий Баник on 19.06.2020.
//  Copyright © 2020 Виталий Баник. All rights reserved.
//

import StoreKit

// MARK: - Constants
fileprivate struct Constants {
    
    static let kSandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt"
    static let kBuyUrl = "https://buy.itunes.apple.com/verifyReceipt"
}

// MARK: - SQStoreKit
public class SQStoreKit: NSObject {
    
// MARK: - Delegates
    public weak var delegate: SQStoreKitDelegate?
    public weak var uiDelegate: SQStoreKitUIDelegate?
    
// MARK: - Properties
    public var getIAPProductsInfoUseCase: GetIAPProductsInfoUseCase?
    public var restartReuestTimeInterval: TimeInterval = 10.0
    
// MARK: - Private properties
    private var productsIds = Set<String>()
    private var productsList = [SKProduct]()
    private var sharedSecret: String?
    private var purchaseInProgress = false
    private var requestTimer: Timer?
    
// MARK: - Singletone
    public static let shared = SQStoreKit()
    private override init() {}
    
// MARK: - Configure method
    public func loadProducts() {
        if !self.canMakePayments() { return }
        
        SKPaymentQueue.default().add(self)
        self.getIAPProductsInfoUseCase?.execute { [weak self] (success, productsInfo, errorMessage) in
            guard success, let productsInfo = productsInfo else {
                print("SQStoreKit >>> Could not get products info for load products! \(errorMessage ?? "")")
                return
            }
            
            self?.productsIds = Set<String>(productsInfo.productsIdentifiers)
            self?.sharedSecret = productsInfo.sharedSecret
            
            self?.loadAvailableProducts()
        }
    }

// MARK: - Publics methods
    
    // доступны ли покупки
    public func canMakePayments() -> Bool {
        let canMakePayments = SKPaymentQueue.canMakePayments()
        print(canMakePayments ? "SQStoreKit >>> Can make payments" : "SQStoreKit >>> Can't make payments")
        #if TARGET_IPHONE_SIMULATOR
        print("Attention! IAPs function only on a real device!")
        #endif
        return canMakePayments
    }
    
    // куплен ли продукт
    public func isPurchasedProduct(_ productIdentifier: String) -> Bool {
        return UserDefaults.standard.bool(forKey: productIdentifier)
    }
     
    // пометить как купленный
    public func markAsPurchasedProduct(_ productIdentifier: String) {
        UserDefaults.standard.set(true, forKey: productIdentifier)
        UserDefaults.standard.synchronize()
    }
    
    // пометить как некупленный
    public func markAsNotPurchasedProduct(_ productIdentifier: String) {
        UserDefaults.standard.set(false, forKey: productIdentifier)
        UserDefaults.standard.synchronize()
    }
    
    // купить продукт
    public func purchaseProduct(_ productIdentifier: String) {
        guard let product = self.getProduct(productIdentifier) else {
            print("SQStoreKit >>> Product identifier is invalid!")
            return
        }
        
        if self.purchaseInProgress {
            print("SQStoreKit >>> Purchase already in progress!")
            return
        }
        
        print("SQStoreKit >>> Will buy product: \(product.localizedTitle)")
        
        if self.isPurchasedProduct(productIdentifier) {
            print("SQStoreKit >>> Can't buy product: \(product.localizedTitle), because already buyed!")
            return
        }
        
        self.delegate?.willPurchaseProduct(product, store: self)
        
        DispatchQueue.main.async {
            self.uiDelegate?.willStartLongProcess()
        }
        
        self.purchaseInProgress = true
        SKPaymentQueue.default().add(SKPayment(product: product))
    }
    
    // получить продукт
    public func getProduct(_ identifier: String) -> SKProduct? {
        return self.productsList.first(where: {$0.productIdentifier == identifier})
    }
    
    // получить все продукты
    public func getProducts() -> [SKProduct] {
        return self.productsList
    }
    
    // сколько доступно продуктов
    public func productsCount() -> Int {
        return self.productsList.count
    }
    
    // восстановить покупки
    public func restorePurchases() {
        DispatchQueue.main.async {
            self.uiDelegate?.willStartLongProcess()
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
// MARK: - Private methods
    @objc private func loadAvailableProducts() {
        print("SQStoreKit >>> Attempt to load products...")
        
        self.requestTimer?.invalidate()
        self.requestTimer = nil
        
        let request = SKProductsRequest.init(productIdentifiers: self.productsIds)
        request.delegate = self
        request.start()
    }
    
    private func updatePurchasedItem(productId: String?, isRestore: Bool) {
        guard let productId = productId else { return }
        
        self.markAsPurchasedProduct(productId)
        
        for product in self.productsList {
            if product.productIdentifier == productId {
                if isRestore {
                    print("SQStoreKit >>> Did restore product: \(product.localizedDescription)")
                    self.delegate?.didRestoreProduct(product, store: self)
                } else {
                    print("SQStoreKit >>> Did purchase product: \(product.localizedDescription)")
                    self.delegate?.didPurchaseProduct(product, store: self)
                }
                
                return
            }
        }
        
        self.delegate?.didRestoreOldProduct(productId, store: self)
    }
    
}

// MARK: - SKProductsRequestDelegate
extension SQStoreKit: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.products.isEmpty {
            print("SQStoreKit >>> Products list is empty")
        }
        
        let sortedProducts = response.products.sorted { $0.price.floatValue < $1.price.floatValue }
        sortedProducts.forEach { print("SQStoreKit >>> Find product: \($0.localizedTitle) - \($0.localizedPrice())") }
        
        self.productsList = sortedProducts
        self.delegate?.didUpdateProductsList(sortedProducts, store: self)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .IAPProductsDidLoadNotification, object: nil)
        }
    }
    
    public func requestDidFinish(_ request: SKRequest) {
        print("SQStoreKit >>> Finish request")
        if request is SKReceiptRefreshRequest {
            self.refreshSubscriptionsStatus()
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("SQStoreKit >>> Receive products list error: \(error.localizedDescription)")
        self.delegate?.updateProductsListError(error, store: self)
        self.restartRequest()
    }
    
    private func restartRequest() {
        print("SQStoreKit >>> Restart request after \(self.restartReuestTimeInterval) sec")
        DispatchQueue.main.async {
            self.requestTimer = Timer.scheduledTimer(timeInterval: self.restartReuestTimeInterval,
                                                     target: self,
                                                     selector: #selector(self.loadAvailableProducts),
                                                     userInfo: nil,
                                                     repeats: false)
            if let timer = self.requestTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
}

// MARK: - SKPaymentTransactionObserver
extension SQStoreKit: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                self.complete(transaction)
                
            case .restored:
                self.restore(transaction)
                
            case .failed:
                self.failed(transaction)
                
            default:
                break
            }
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async {
            self.uiDelegate?.didFinishLongProcess()
        }
        print("SQStoreKit >>> Restore product failed with error: \(error.localizedDescription)")
        self.delegate?.restoreProductError(error, store: self)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async {
            self.uiDelegate?.didFinishLongProcess()
        }
    }
    
    private func complete(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction complete")
        self.updatePurchasedItem(productId: transaction.payment.productIdentifier, isRestore: false)
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        DispatchQueue.main.async {
            self.uiDelegate?.didFinishLongProcess()
        }
    }
    
    private func restore(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction restore")
        self.updatePurchasedItem(productId: transaction.original?.payment.productIdentifier, isRestore: true)
        self.refreshSubscriptionsStatus()
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        DispatchQueue.main.async {
            self.uiDelegate?.didFinishLongProcess()
        }
    }
    
    private func failed(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction failed with error: \(transaction.error?.localizedDescription ?? "")")
        if (transaction.error as? SKError)?.code == .paymentCancelled {
            if let error = transaction.error {
                self.delegate?.purchaseProductCanceled(error, store: self)
            }
            
            #if TARGET_IPHONE_SIMULATOR
            self.updatePurchasedItem(productId: transaction.payment.productIdentifier, isRestore: false)
            #endif
            
        } else {
            if let error = transaction.error {
                self.delegate?.purchaseProductError(error, store: self)
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        DispatchQueue.main.async {
            self.uiDelegate?.didFinishLongProcess()
        }
    }
    
}

// MARK: - AutoSubscribes methods
extension SQStoreKit {

// MARK: - Public methods

    // активна ли еще автоподписка
    public func isActiveSubscription(_ productIdentifier: String) -> Bool {
        guard let expirationDate = self.expirationDateForSubscriptionWithId(productIdentifier) else { return false }
        return expirationDate > Date()
    }

// MARK: - Private methods
    private func refreshSubscriptionsStatus() {
        guard let receiptUrl = Bundle.main.appStoreReceiptURL else {
            self.refreshReceipt()
            return
        }

        #if DEBUG
        let urlString = Constants.kSandboxUrl
        #else
        let urlString = Constants.kBuyUrl
        #endif

        let receiptData = try? Data(contentsOf: receiptUrl).base64EncodedString()
        let requestData = ["receipt-data": receiptData ?? "",
                           "password": self.sharedSecret as Any,
                           "exclude-old-transactions": true] as [String: Any]

        guard let url = URL(string: urlString) else {
            print("SQStoreKit >>> Invalid url")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")

        let httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request)  { (data, response, error) in
            DispatchQueue.main.async {
                if let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                    let receiptDictionary = json as? [String: Any] {

                    self.parseReceipt(receiptDictionary)
                    return

                } else {
                    print("SQStoreKit >>> Error validating receipt: \(error?.localizedDescription ?? "")")
                }
            }
        }.resume()
    }

    private func refreshReceipt() {
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }

    private func parseReceipt(_ json: [String: Any]) {
        guard let receiptsArray = json["latest_receipt_info"] as? [[String: Any]] else { return }
        for receipt in receiptsArray {
            guard let productId = receipt["product_id"] as? String,
                let expiresDateString = receipt["expires_date"] as? String else {

                print("SQStoreKit >>> Invalid receipt")
                continue
            }

            let cancellationDate = receipt["cancellation_date"] as? String

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"

            if let date = formatter.date(from: cancellationDate ?? expiresDateString), date > Date() {
                UserDefaults.standard.set(date, forKey: productId)
                UserDefaults.standard.synchronize()
            }
        }
    }

    private func expirationDateForSubscriptionWithId(_ id: String) -> Date? {
        return UserDefaults.standard.object(forKey: id) as? Date
    }

}

