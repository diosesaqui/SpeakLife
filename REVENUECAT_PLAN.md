# RevenueCat Integration Plan

## Overview

Replace the custom StoreKit layer (`SubscriptionStore.swift` + `InAppPurchases.swift`) with RevenueCat's SDK. The public interface stays the same — `isPremium`, purchase/restore methods, etc. — so no view code needs to change.

---

## What's Needed From You Before Code Goes Live

1. **RevenueCat API Key** — from https://app.revenuecat.com → your app → API Keys → Public app-specific key (starts with `appl_...`)
2. **RevenueCat App Created** — make sure there's an app set up in RC dashboard linked to your Apple App Store app
3. **Products Configured in RC** — go to RC dashboard → Products, and make sure all product IDs are added:
   - `SpeakLifeLifetime`
   - `SpeakLife1YR99`, `SpeakLife1YR49`, `SpeakLife1YR39`, `SpeakLife1YR29`, `SpeakLife1YR19`
   - `SpeakLife1MO9`, `SpeakLife1MO7`, `SpeakLife1MO4`, `SpeakLife1MO2`
   - `SpeakLife1Wk5`
   - `Devotionals30SL`
4. **Entitlements Set Up in RC** — create an entitlement called `premium` and attach all the subscription + lifetime products to it. Also create `devotional` entitlement for `Devotionals30SL`.
5. **Offerings Configured** — create a default Offering in RC and assign packages (yearly, monthly, weekly, lifetime). This is what controls which products show — replaces the Remote Config flags.

---

## Implementation Steps

### Step 1 — Add RevenueCat via Swift Package Manager

In Xcode:
- File → Add Package Dependencies
- URL: `https://github.com/RevenueCat/purchases-ios`
- Version: latest (`4.x` or `5.x`)
- Add `RevenueCat` product to the SpeakLife target

In `Package.resolved`, this will add a new pin for `purchases-ios`.

### Step 2 — Configure SDK at App Launch

In `SpeakLifeApp.swift` (or wherever Firebase is initialized):

```swift
import RevenueCat

// In app init or AppDelegate
Purchases.logLevel = .debug // remove for prod
Purchases.configure(withAPIKey: "appl_YOUR_KEY_HERE")

// Optional: set user ID if you have one
// Purchases.shared.logIn("user-id") { customerInfo, created, error in }
```

### Step 3 — Create `RevenueCatManager.swift`

New file at `SpeakLife/Services/IAP/RevenueCatManager.swift`:

```swift
import RevenueCat
import SwiftUI
import Combine

final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var isPremium: Bool = false
    @Published var isDevotionalPremium: Bool = false
    @Published var currentOffering: Offering? = nil
    @Published var packages: [Package] = []
    
    // Map to match existing SubscriptionStore interface
    @Published var currentOfferedDiscount: Package? = nil
    @Published var currentOfferedLifetime: Package? = nil
    @Published var currentOfferedMonthly: Package? = nil
    @Published var currentOfferedWeekly: Package? = nil
    
    init() {
        Task { await refreshCustomerInfo() }
        Task { await fetchOfferings() }
    }
    
    // MARK: - Check entitlements
    func refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
                self.isDevotionalPremium = customerInfo.entitlements["devotional"]?.isActive == true
            }
        } catch {
            print("RC customerInfo error: \(error)")
        }
    }
    
    // MARK: - Load offerings
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                self.currentOffering = offerings.current
                self.packages = offerings.current?.availablePackages ?? []
                // Map packages to existing UI slots
                self.currentOfferedLifetime = packages.first { $0.storeProduct.productIdentifier == lifetimeID }
                self.currentOfferedMonthly = packages.first { $0.packageType == .monthly }
                self.currentOfferedWeekly = packages.first { $0.packageType == .weekly }
                self.currentOfferedDiscount = packages.first { $0.storeProduct.productIdentifier == discountID }
            }
        } catch {
            print("RC offerings error: \(error)")
        }
    }
    
    // MARK: - Purchase
    func purchase(package: Package) async throws -> CustomerInfo {
        let result = try await Purchases.shared.purchase(package: package)
        await refreshCustomerInfo()
        return result.customerInfo
    }
    
    // MARK: - Restore
    func restore() async throws -> CustomerInfo {
        let customerInfo = try await Purchases.shared.restorePurchases()
        await MainActor.run {
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
        }
        return customerInfo
    }
}
```

### Step 4 — Update `SubscriptionStore.swift` (migration bridge)

Two options:
- **Option A (recommended):** Keep `SubscriptionStore` as the source of truth but delegate IAP calls to RC. Views don't change.
- **Option B:** Refactor views to use `RevenueCatManager` directly. More work but cleaner long-term.

For Option A, modify `SubscriptionStore` to:
- Remove `StoreKit.Transaction` listener
- Remove `Product.products()` fetching
- Replace `purchase()` calls with `RevenueCatManager.shared.purchase()`
- Replace `restore()` with `RevenueCatManager.shared.restore()`
- Drive `isPremium` from RC entitlements instead of `subscriptionGroupStatus`

### Step 5 — Remove StoreKit Custom Code

Once RC is wired up:
- Remove `listenForTransactions()`
- Remove `updateCustomerProductStatus()`
- Remove `requestProducts()`
- Keep `InAppPurchases.swift` product ID definitions (still needed for RC entitlement mapping if using Option A)

### Step 6 — Analytics Integration

RC has built-in analytics, but also supports sending events to Firebase:
```swift
// In Purchases.configure:
Purchases.shared.attribution.setFirebaseAppInstanceID(Analytics.appInstanceID() ?? "")
```

This lets RC attribute purchases back to Firebase campaigns.

---

## Files Modified

| File | Change |
|------|--------|
| `SpeakLifeApp.swift` | Add `Purchases.configure(...)` |
| `Services/IAP/SubscriptionStore.swift` | Replace StoreKit calls with RC |
| `Services/IAP/InAppPurchases.swift` | Keep product ID definitions |
| `Package.resolved` | New RC dependency pin |

## New Files

| File | Purpose |
|------|---------|
| `Services/IAP/RevenueCatManager.swift` | RC wrapper |

---

## Testing Checklist

- [ ] New purchase completes and `isPremium` flips to `true`
- [ ] App kill + reopen → still premium (entitlement persists)
- [ ] Restore purchases works for existing StoreKit subscribers
- [ ] Sandbox subscription + expiry correctly revokes premium
- [ ] Analytics events fire in Firebase after purchase
- [ ] RC dashboard shows the purchase in subscriber list

---

## What RC Gives You Out of the Box

- **Subscriber dashboard** — see all users, their status, LTV, churn
- **A/B test paywalls** — swap offerings remotely without app update
- **Grace period handling** — automatic for billing retry
- **Cross-platform** — if you ever build Android, same entitlements
- **Subscription events webhooks** — cancellations, renewals, billing issues

---

## Estimated Effort

- Adding SDK + configure: 30 min
- RevenueCatManager + SubscriptionStore migration: 3–4 hours
- Testing in sandbox: 1–2 hours
- Total: ~1 day of focused dev work
