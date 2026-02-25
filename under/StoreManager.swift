import Foundation
import StoreKit
import Combine

@MainActor
class StoreManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published var showExpirationAlert = false
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium")
    var viewModel: MatchViewModel?
    
    // App Store Connect'teki Product ID'lerinizle tam eşleşmelidir
    private let productIDs = ["yillik_plan", "aylik_plan", "haftalik_plan"]
    
    // Arka planda gelen güncellemeleri dinlemek için
    private var transactionListener: Task<Void, Error>? = nil
    
    // MARK: - Initialization
    init() {
        // Dinleyiciyi başlat (Yenilemeler ve dış iptaller için)
        transactionListener = listenForTransactions()
        
        Task {
            await fetchProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - App Store Operations
    
    /// Ürünleri App Store'dan çeker
    func fetchProducts() async {
        print("🔄 StoreKit: Ürünler çekiliyor...")
        do {
            let storeProducts = try await Product.products(for: productIDs)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
            
            print("✅ StoreKit: \(self.products.count) ürün başarıyla yüklendi.")
            if self.products.isEmpty {
                print("⚠️ UYARI: StoreKit yapılandırmasını veya ID'leri kontrol edin.")
            }
        } catch {
            print("❌ StoreKit Hatası: Ürünler çekilemedi - \(error.localizedDescription)")
        }
    }
    
    /// Satın alma işlemini başlatır
    func buyProduct(_ productID: String) async throws {
        guard let product = products.first(where: { $0.id == productID }) else {
            print("❌ StoreKit: Ürün bulunamadı: \(productID)")
            return
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Apple'dan gelen veriyi doğrula
            let transaction = try checkVerified(verification)
            
            // ✅ YENİ: Deneme Süresi (Trial) ve Ücret Kontrolü
            var finalAmount: Double = 0.0
            var planName: String = product.id
            
            // Eğer offerType varsa ve introductory (deneme/tanıtım) ise Trial olarak işaretle
            if let offer = transaction.offer {
                if offer.type == .introductory {
                    finalAmount = 0.0
                    planName = "Trial: \(product.id)"
                }
            } else {
                // Gerçek satın alma veya deneme süresi bittikten sonraki ilk yenileme
                finalAmount = NSDecimalNumber(decimal: product.price).doubleValue
            }
            
            // ✅ Firebase Kaydı: ViewModel üzerinden dinamik verileri gönder
            // Not: ViewModel'ın StoreManager içinde tanımlı olduğundan emin ol
            viewModel?.recordSuccessfulPayment( // 👈 Soru işareti ekledik
                planID: planName,
                amount: finalAmount
            )
            
            print("✅ Satın Alma Başarılı: \(transaction.productID) - Tutar: \(finalAmount)")
            
            // UI ve Yerel Durumu Güncelle
            await updatePurchasedProducts()
            
            // İşlemi Apple tarafında kapat
            await transaction.finish()
            
        case .userCancelled:
            print("👤 Kullanıcı işlemi iptal etti.")
        case .pending:
            print("⏳ İşlem beklemede (Ebeveyn onayı gerekebilir).")
        @unknown default:
            break
        }
    }
    
    /// Mevcut abonelik yetkilerini kontrol eder ve senkronize eder
    func updatePurchasedProducts() async {
        var hasActiveSubscription = false
        var currentPurchasedIDs = Set<String>()
        
        // Mevcut aktif yetkileri tek tek kontrol et
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Revoke (Geri çekilme) edilmemiş ve süresi dolmamış ürünleri al
                if transaction.revocationDate == nil {
                    hasActiveSubscription = true
                    currentPurchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("⚠️ Doğrulanamayan işlem atlandı.")
            }
        }
        
        // UI Güncellemeleri
        updateUIAfterSync(hasActive: hasActiveSubscription, ids: currentPurchasedIDs)
    }
    
    // MARK: - Helper Methods
    
    private func updateUIAfterSync(hasActive: Bool, ids: Set<String>) {
        // Eski durumla karşılaştırıp abonelik bitmişse alert ver
        if self.isPremium && !hasActive {
            self.showExpirationAlert = true
        }
        
        self.purchasedProductIDs = ids
        self.isPremium = hasActive
        UserDefaults.standard.set(hasActive, forKey: "isPremium")
        
        // ViewModel'lara haber ver
        NotificationCenter.default.post(name: NSNotification.Name("PremiumStatusChanged"), object: nil)
        print("🍏 StoreKit Durumu: Premium = \(hasActive)")
    }
    
    /// Apple tarafında uygulama dışı gerçekleşen (ayarlar menüsünden iptal vb.) değişiklikleri dinler
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Verileri güncelle
                    await self.updatePurchasedProducts()
                    
                    // İşlemi bitir
                    await transaction.finish()
                } catch {
                    print("❌ Transaction dinleme hatası.")
                }
            }
        }
    }
    
    /// Veri doğrulama yardımcı fonksiyonu
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Support Types
enum StoreError: Error {
    case failedVerification
}
