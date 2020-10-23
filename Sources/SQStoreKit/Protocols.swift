//
//  Protocols.swift
//  SQStoreKit
//
//  Created by Виталий Баник on 19.06.2020.
//  Copyright © 2020 Виталий Баник. All rights reserved.
//

import StoreKit
#if !os(macOS)
import UIKit
#endif

// MARK: - ProductIdentifier
public protocol ProductIdentifier {
    
    func productId() -> String
    static func allIDs() -> [String]
}

// MARK: - SQStoreActivityView
@objc public protocol SQStoreActivityView {}

// MARK: - SQStoreKitUIDelegate
#if !os(macOS)
public protocol SQStoreKitUIDelegate: UIViewController {}
#else
public protocol SQStoreKitUIDelegate: NSViewController {}
#endif

// MARK: - SQStoreKitDelegate
public protocol SQStoreKitDelegate: class {

    // Вызывается когда приобретен инап
    func didPurchaseProduct(_ product: SKProduct, store: SQStoreKit)

    // Вызывается когда востановлен инап
    func didRestoreProduct(_ product: SKProduct, store: SQStoreKit)

    // Вызывается когда прогружен список инапов (опциональный)
    func didUpdateProductsList(_ productsList: [SKProduct], store: SQStoreKit)

    // Ошибка загрузки инапов (опциональный)
    func updateProductsListError(_ error: Error, store: SQStoreKit)
    
    // Ошибка покупки инапов (опциональный)
    func purchaseProductError(_ error: Error, store: SQStoreKit)

    // Ошибка востановления инапов (опциональный)
    func restoreProductError(_ error: Error, store: SQStoreKit)

    // Покупка отменена пользователем (опциональный)
    func purchaseProductCanceled(_ error: Error, store: SQStoreKit)

    // Будет куплен продукт (опциональный)
    func willPurchaseProduct(_ product: SKProduct, store: SQStoreKit)

    // Был востановлен старый IAP, которого нет в массиве продуктов (опциональный)
    func didRestoreOldProduct(_ productIdentifire: String, store: SQStoreKit)
}

// MARK: - SQStoreKitDelegate implementation for optional funcs
extension SQStoreKitDelegate {
    
    func didUpdateProductsList(_ productsList: [SKProduct], store: SQStoreKit) {}
    func updateProductsListError(_ error: Error, store: SQStoreKit) {}
    func purchaseProductError(_ error: Error, store: SQStoreKit) {}
    func restoreProductError(_ error: Error, store: SQStoreKit) {}
    func purchaseProductCanceled(_ error: Error, store: SQStoreKit) {}
    func willPurchaseProduct(_ product: SKProduct, store: SQStoreKit) {}
    func didRestoreOldProduct(_ productIdentifire: String, store: SQStoreKit) {}
}
