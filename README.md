# SQStoreKit


## Использование:

1. Определить enum со списком BundleIdentifiers продуктов (инапов и автоподписок), который конфермит протокол ProductIdentifier
```
public protocol ProductIdentifier {
    
    func productId() -> String
    static func allIds() -> [String]
}

enum IAPBundles: String, CaseIterable, ProductIdentifier {

    case firstProduct
    case secondProduct
    case oneMonthSubscribe

    func productId() -> String {
        return Bundle.main.bundleIdentifier?.appending(".\(self.rawValue)") ?? ""
    }

    static func allIds() -> [String] {
        return IAPBundles.allCases.map { Bundle.main.bundleIdentifier?.appending(".\($0.rawValue)") ?? "" }
    }
}
```
2. Инициализировать менеджер этим enum'ом и sharedSecret автоподписок (если есть)
```
SQStoreKit.shared.initWithProductsEnum(IAPBundles.self, sharedSecret: "yui3y4iuy534i")
```
3. Можно совершать покупки продуктов и проверять куплены ли определенные инапы
```
SQStoreKit.shared.purchaseProduct(IAPBundles.firstProduct)
SQStoreKit.shared.purchaseProduct(IAPBundles.oneMonthSubscribe)
SQStoreKit.shared.isPurchasedProduct(IAPBundles.oneMonthSubscribe)
SQStoreKit.shared.isActiveSubscription(IAPBundles.oneMonthSubscribe)
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

- SQStoreKit.shared.uiDelegate - контроллер для отображения activityView
```
public protocol SQStoreKitUIDelegate: UIViewController {}
```

## Параметры
- view для отображения во время выполнения запроса покупки
```
@objc public protocol SQStoreActivityView {}

open var activityView: SQStoreActivityView?
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

