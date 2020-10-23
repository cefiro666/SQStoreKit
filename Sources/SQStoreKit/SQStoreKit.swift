//
//  SQStoreKit.swift
//  SQStoreKit
//
//  Created by Виталий Баник on 19.06.2020.
//  Copyright © 2020 Виталий Баник. All rights reserved.
//

import StoreKit
import SystemConfiguration

#if !os(macOS)
import UIKit
#endif

// MARK: - Constants
fileprivate struct Constants {
    
    static let kRestartReuestTimeInterval: TimeInterval = 15.0
    static let kSandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt"
    static let kBuyUrl = "https://buy.itunes.apple.com/verifyReceipt"
}

// MARK: - SQStoreKit
open class SQStoreKit: NSObject {
    
// MARK: - Public properties
    open var activityView: SQStoreActivityView?
    
// MARK: - Delegates
    public weak var delegate: SQStoreKitDelegate?
    public weak var uiDelegate: SQStoreKitUIDelegate?
    
// MARK: - Private properties
    private var productsIDs = Set<String>()
    private var productsList = [SKProduct]()

    private var sharedSecret: String?
    
    private var purchaseInProgress = false
    
    private var requestTimer: Timer?
    
// MARK: - Singletone
    public static let shared = SQStoreKit()

// MARK: - Init
    private override init() {}
    
// MARK: - Configure method
    open func initWithProductsEnum(_ productsEnum: ProductIdentifier.Type, sharedSecret: String? = nil) {
        guard self.canMakePayments(),
            !productsEnum.allIDs().isEmpty else {
                
            print("SQStoreKit >>> Error init store")
            return
        }
        
        SKPaymentQueue.default().add(self)
        
        self.productsIDs = Set<String>(productsEnum.allIDs())
        self.sharedSecret = sharedSecret
        
        self.loadProducts()
    }

// MARK: - Publics methods
    
    // доступны ли покупки
    open func canMakePayments() -> Bool {
        print(SKPaymentQueue.canMakePayments() ?
            "SQStoreKit >>> Can make payments" : "SQStoreKit >>> Can't make payments")
        
        return SKPaymentQueue.canMakePayments()
    }
    
    // куплен ли продукт
    open func isPurchasedProduct(_ productIdentifier: ProductIdentifier) -> Bool {
        return UserDefaults.standard.bool(forKey: productIdentifier.productId())
    }
    
    // пометить как купленный
    open func markAsPurchasedProduct(_ productIdentifier: ProductIdentifier) {
        UserDefaults.standard.set(true, forKey: productIdentifier.productId())
        UserDefaults.standard.synchronize()
    }
    
    // пометить как некупленный
    open func markAsNotPurchasedProduct(_ productIdentifier: ProductIdentifier) {
        UserDefaults.standard.set(false, forKey: productIdentifier.productId())
        UserDefaults.standard.synchronize()
    }
    
    // купить продукт
    open func purchaseProduct(_ productsIdentifier: ProductIdentifier) {
        guard let product = self.getProduct(productsIdentifier), !self.purchaseInProgress else {
            print("SQStoreKit >>> Product identifier is invalid or purchase in progress")
            return
        }
        
        print("SQStoreKit >>> Will buy product: \(product.localizedTitle)")
        
        guard !self.isPurchasedProduct(productsIdentifier) else {
            print("SQStoreKit >>> Can't buy product \(product.localizedTitle), because already buyed!")
            return
        }
        
        self.delegate?.willPurchaseProduct(product, store: self)
        
        self.addActivityView()
        self.purchaseInProgress = true
        SKPaymentQueue.default().add(SKPayment(product: product))
    }
    
    // получить продукт по идентификатору
    open func getProduct(_ productsIdentifier: ProductIdentifier) -> SKProduct? {
        return self.productsList.first(where: {$0.productIdentifier == productsIdentifier.productId()})
    }
    
    // получить все продукты
    open func getProducts() -> [SKProduct] {
        return self.productsList
    }
    
    // сколько доступно продуктов
    open func productsCount() -> Int {
        return self.productsList.count
    }
    
    // восстановить покупки
    open func restorePurchases() {
        self.addActivityView()
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
// MARK: - Private methods
    @objc private func loadProducts() {
        print("SQStoreKit >>> Attempt to load products...")
        
        self.requestTimer?.invalidate()
        self.requestTimer = nil
        
        let request = SKProductsRequest.init(productIdentifiers: self.productsIDs)
        request.delegate = self
        request.start()
    }
    
    private func updatePurchasedItem(productId: String?, isRestore: Bool) {
        guard let productId = productId else { return }
        
        self.markAsPurchasedProduct(productId)
        
        for product in self.productsList {
            if product.productIdentifier == productId {
                if isRestore {
                    print("SQStoreKit >>> Did restore product \(product.localizedDescription)")
                    self.delegate?.didRestoreProduct(product, store: self)
                } else {
                    print("SQStoreKit >>> Did purchase product \(product.localizedDescription)")
                    self.delegate?.didPurchaseProduct(product, store: self)
                }
                
                return
            }
        }
        
        self.delegate?.didRestoreOldProduct(productId, store: self)
    }
    
    private func markAsPurchasedProduct(_ id: String) {
        UserDefaults.standard.set(true, forKey: id)
        UserDefaults.standard.synchronize()
    }

}

// MARK: - SKProductsRequestDelegate
extension SQStoreKit: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.products.isEmpty {
            print("SQStoreKit >>> Products list is empty")
            self.restartRequest()
        }
        
        let sortedProducts = response.products.sorted { $0.price.floatValue < $1.price.floatValue }
        sortedProducts.forEach { print("SQStoreKit >>> Find product \($0.localizedTitle) - \($0.localizedPrice())") }
        
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
        print("SQStoreKit >>> Error receive products list")
        self.delegate?.updateProductsListError(error, store: self)
        self.restartRequest()
    }
    
    private func restartRequest() {
        print("SQStoreKit >>> Restart request after \(Constants.kRestartReuestTimeInterval) sec")
        DispatchQueue.main.async {
            self.requestTimer = Timer.scheduledTimer(timeInterval: Constants.kRestartReuestTimeInterval,
                                                     target: self,
                                                     selector: #selector(self.loadProducts),
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
        self.removeActivityView()
        print("SQStoreKit >>> Restore product failed with error \(error.localizedDescription)")
        self.delegate?.restoreProductError(error, store: self)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        self.removeActivityView()
    }
    
    private func complete(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction complete")
        self.updatePurchasedItem(productId: transaction.payment.productIdentifier, isRestore: false)
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        self.removeActivityView()
    }
    
    private func restore(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction restore")
        self.updatePurchasedItem(productId: transaction.original?.payment.productIdentifier, isRestore: true)
        self.refreshSubscriptionsStatus()
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        self.removeActivityView()
    }
    
    private func failed(_ transaction: SKPaymentTransaction) {
        print("SQStoreKit >>> Transaction failed with error \(transaction.error?.localizedDescription ?? "")")
        if (transaction.error as? SKError)?.code == .paymentCancelled {
            if let error = transaction.error {
                self.delegate?.purchaseProductError(error, store: self)
            }
            
            #if TARGET_IPHONE_SIMULATOR
            self.updatePurchasedItem(productId: transaction.payment.productIdentifier, isRestore: false)
            #endif
            
        } else {
            if let error = transaction.error {
                self.delegate?.purchaseProductCanceled(error, store: self)
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchaseInProgress = false
        self.removeActivityView()
    }
    
}

// MARK: - SQStoreActivityView
extension SQStoreKit {

    private func addActivityView() {
        DispatchQueue.main.async {
            if let activityView = self.uiDelegate?.view.subviews.first(where: { $0.conforms(to: SQStoreActivityView.self) }) {
                activityView.removeFromSuperview()
            }
            
            #if !os(macOS)
            guard let activityView = self.activityView as? UIView else { return }
            #else
            guard let activityView = self.activityView as? NSView else { return }
            #endif
            
            self.uiDelegate?.view.addSubview(activityView)
            print("SQStoreKit >>> Add activityView")
        }
    }
    
    private func removeActivityView() {
        DispatchQueue.main.async {
            if let activityView = self.uiDelegate?.view.subviews.first(where: { $0.conforms(to: SQStoreActivityView.self) }) {
                activityView.removeFromSuperview()
                print("SQStoreKit >>> Remove activityView")
            }
        }
    }

}

// MARK: - AutoSubscribes methods
extension SQStoreKit {
    
// MARK: - Public methods
    
    // активна ли еще автоподписка
    open func isActiveSubscription(_ productsIdentifier: ProductIdentifier) -> Bool {
        guard let expirationDate = self.expirationDateForSubscriptionWithId(productsIdentifier.productId()) else { return false }
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

// MARK: - isConnectedToNetwork
public class DeviceNetwork {
    
    class func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
}
