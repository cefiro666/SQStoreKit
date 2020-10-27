//
//  Extensions.swift
//  SQStoreKit
//
//  Created by Виталий Баник on 19.06.2020.
//  Copyright © 2020 Виталий Баник. All rights reserved.
//

import StoreKit

// MARK: - Notification.Name
extension Notification.Name {
     
    public static let IAPProductsDidLoadNotification = Notification.Name("IAPProductsDidLoadNotification")
}

// MARK: - SKProduct
extension SKProduct {
    
    public func priceForPeriodPerMonthsCount(_ monthsCount: Int) -> Float {
        return self.price.floatValue / Float(monthsCount)
    }
    
    public func localizedPrice() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.formatterBehavior = .behavior10_4
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = self.priceLocale
        let localizedPriceString = numberFormatter.string(from: self.price) ?? "price error"
        
        return localizedPriceString
    }
    
}
