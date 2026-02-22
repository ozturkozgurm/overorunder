import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    // ✅ Kritik: Kendi içindeki storeManager'ı sildik, viewModel üzerindekini kullanıyoruz.
    @EnvironmentObject var viewModel: MatchViewModel
    
    @State private var selectedPlanID: String = "yillik_plan"
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    let currentSelectedPlanID: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 1. ÜST KAPATMA
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // BAŞLIK
                VStack(spacing: 8) {
                    Text("PREMIUM'A GEÇ")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // ✅ ViewModel'daki storeManager üzerinden dinamik mesaj
                    Text(viewModel.storeManager.purchasedProductIDs.isEmpty ? "Tüm liglerdeki tahminlere ve canlı analizlere sınırsız erişim sağlayın." : "Premium üyeliğiniz aktif!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // 2. PAKET SEÇENEKLERİ
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        optionRow(id: "yillik_plan", title: "Yıllık Plan", price: "₺999.99", period: "/ Yıl", discount: "En Avantajlı %50 İndirim", isPopular: true)
                        optionRow(id: "aylik_plan", title: "Aylık Plan", price: "₺149.99", period: "/ Ay", discount: nil, isPopular: false)
                        optionRow(id: "haftalik_plan", title: "Haftalık Plan", price: "₺49.99", period: "/ Hafta", discount: nil, isPopular: false)
                    }
                    .padding(.horizontal)
                }
                
                // 3. AVANTAJLAR (Eksiksiz)
                VStack(alignment: .leading, spacing: 14) {
                    BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Yüksek Başarı Oranlı Analizler")
                    BenefitRow(icon: "bell.badge.fill", text: "Anlık Maç Bildirimleri")
                    BenefitRow(icon: "shield.fill", text: "Reklamsız Deneyim")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 25)
                
                // 4. AKSİYON BUTONLARI (Duruma Göre Değişir)
                if !viewModel.storeManager.purchasedProductIDs.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Aboneliğiniz Aktif").font(.headline).foregroundColor(.white)
                        }
                        Button("Aboneliği Yönet") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: { purchaseProcess() }) {
                        ZStack {
                            Text("ABONELİĞİ BAŞLAT")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.black)
                                .opacity(isLoading ? 0 : 1)
                            
                            if isLoading { ProgressView().tint(.black) }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.white)
                        .cornerRadius(18)
                        .padding(.horizontal)
                    }
                    .disabled(isLoading)
                }
                
                // ALT BİLGİ VE RESTORE
                HStack(spacing: 20) {
                    Button("Satın Alımları Geri Yükle") {
                        Task { try? await AppStore.sync() }
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    
                    Text("•")
                    
                    Text("İptal Edilebilir")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 20)
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Bir sorun oluştu.")
        }
    }
    
    // MARK: - Satın Alma Süreci (Apple Ekranını Tetikler)
    private func purchaseProcess() {
        Task {
            isLoading = true
            do {
                // 1. Satın almayı başlat
                try await viewModel.storeManager.buyProduct(selectedPlanID)
                
                // 2. ÖNEMLİ: Apple'ın işlemi sunucuda bitirmesi için 1 saniye bekle
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // 3. Durumu güncelle
                await viewModel.storeManager.updatePurchasedProducts()
                
                // 4. Eğer satın alma gerçekten başarılıysa ekranı kapat
                if viewModel.storeManager.isPremium {
                    dismiss()
                }
            } catch {
                print("Hata: \(error.localizedDescription)")
                showError = true
            }
            isLoading = false
        }
    }
    
    // MARK: - Seçenek Satırı (Eksiksiz Senkronizasyon)
    private func optionRow(id: String, title: String, price: String, period: String, discount: String?, isPopular: Bool) -> some View {
        let isPurchased = viewModel.storeManager.purchasedProductIDs.contains(id)
        let isAnyRealPurchase = !viewModel.storeManager.purchasedProductIDs.isEmpty
        let isActiveSelection = selectedPlanID == id
        
        return SubscriptionOptionRow(
            id: id,
            title: title,
            price: price,
            period: period,
            discount: discount,
            isPopular: isPopular,
            isActiveSelection: isActiveSelection,
            isPurchased: isPurchased,
            isAnyPlanActive: isAnyRealPurchase,
            selectedPlanID: $selectedPlanID
        ) {
            if !isAnyRealPurchase {
                selectedPlanID = id
            }
        }
    }
}

// MARK: - Destekleyici Tasarım Yapıları

struct SubscriptionOptionRow: View {
    let id: String
    let title: String
    let price: String
    let period: String
    let discount: String?
    let isPopular: Bool
    let isActiveSelection: Bool
    let isPurchased: Bool
    let isAnyPlanActive: Bool
    @Binding var selectedPlanID: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isPurchased ? .blue : .white)
                        
                        if isPurchased {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("MEVCUT PLAN")
                                .font(.system(size: 8, weight: .black))
                                .padding(4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    if let discount = discount {
                        Text(discount)
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if isPopular && !isPurchased {
                        Text("EN POPÜLER")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(5)
                    }
                    Text(price)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(isPurchased ? .blue : Color(red: 0.2, green: 0.6, blue: 1.0))
                    
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isPurchased ? Color.blue.opacity(0.1) : (isActiveSelection ? Color.blue.opacity(0.15) : Color.white.opacity(0.05)))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isPurchased ? Color.blue : (isActiveSelection ? Color.blue : Color.clear), lineWidth: isPurchased ? 3 : 2)
            )
            .opacity(isAnyPlanActive && !isPurchased ? 0.4 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAnyPlanActive)
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
