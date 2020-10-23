# SQStoreKit


## Использование:

1. Определить enum со списком BundleIdentifiers продуктов (инапов и автоподписок), который конфермит протокол IAPBundle:
```
public protocol IAPBundle {
    
    func productId() -> String
    static func allIds() -> [String]
}

enum TestIAPBundles: String, CaseIterable, IAPBundle {

    case firstProduct
    case secondProduct
    case oneMonthSubscribe

    func productId() -> String {
        return Bundle.main.bundleIdentifier?.appending(".\(self.rawValue)") ?? ""
    }

    static func allIds() -> [String] {
        return TestIAPBundles.allCases.map { Bundle.main.bundleIdentifier?.appending(".\($0.rawValue)") ?? "" }
    }
}
```
2. Инициализировать менеджер этим enum'ом и sharedSecret автоподписок (если есть)
```
SQStoreKit.shared.initWithProductsEnum(TestIAPBundles.self, sharedSecret: "yui3y4iuy534i")
```
3. Можно совершать покупки продуктов и проверять куплены ли определенные инапы
```
SQStoreKit.shared.purchaseProduct(TestIAPBundles.firstProduct)
SQStoreKit.shared.purchaseProduct(TestIAPBundles.oneMonthSubscribe)
SQStoreKit.shared.isPurchasedProduct(TestIAPBundles.oneMonthSubscribe)
SQStoreKit.shared.isActiveSubscription(TestIAPBundles.oneMonthSubscribe)
```
## Делегаты

- SQStoreKit.shared.delegate - обрабатывает события покупок (покупка, восстановление и тд)
```
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
```

- SQStoreKit.shared.uiDelegate - делеагат для методов отображения activityView во время работы библиотеки
```
public protocol SQStoreKitUIDelegate: class {
    func acivityViewWillAppear()
    func acivityViewWillDisappear()
}
```

## Публичные методы
```
// доступны ли покупки
open func canMakePayments() -> Bool 

// куплен ли продукт
open func isPurchasedProduct(_ productIdentifier: ProductIdentifier)

// пометить как купленный
open func markAsPurchasedProduct(_ productIdentifier: ProductIdentifier)

// пометить как некупленный
open func markAsNotPurchasedProduct(_ productIdentifier: ProductIdentifier) 

// купить продукт
open func purchaseProduct(_ productsIdentifier: ProductIdentifier) 

// получить продукт по идентификатору
open func getProduct(_ productsIdentifier: ProductIdentifier) -> SKProduct? 

// сколько доступно продуктов
open func productsCount() -> Int 

// восстановить покупки
open func restorePurchases() 

// активна ли еще автоподписка
open func isActiveSubscription(_ productsIdentifier: ProductIdentifier) -> Bool
```

