//
//  Errors.swift
//  SQStoreKit
//
//  Created by Виталий Баник on 22.06.2020.
//  Copyright © 2020 Виталий Баник. All rights reserved.
//

import Foundation

// MARK: - SQStoreKitError
enum SQStoreKitError: Error {
    
    case noProductIDsFound
    case noProductsFound
    case paymentWasCancelled
    case productRequestFailed
}

// MARK: - SQStoreKitError
extension SQStoreKitError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .noProductIDsFound: return "No In-App Purchase product identifiers were found."
        case .noProductsFound: return "No In-App Purchases were found."
        case .paymentWasCancelled: return "In-App Purchase process was cancelled."
        case .productRequestFailed: return "Unable to fetch available In-App Purchase products at the moment."
        }
    }
}
