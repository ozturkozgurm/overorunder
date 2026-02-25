import SwiftUI
import StoreKit // Apple Değerlendirme popup'ı için
import UserNotifications // Bildirim izinleri için

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: MatchViewModel
    
    // --- PERSISTENT STATE (Cihaz hafızasında tutulur) ---
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("selectedLanguage") private var selectedLanguage = "English"
    @AppStorage("selectedTheme") private var selectedTheme = "System"
    
    // --- UI STATE ---
    @State private var showPaywall = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var showFeedback = false
    
    // GitHub Pages linkleri
    private let privacyURL = URL(string: "https://ozturkozgurm.github.io/overorunder-legal/privacy.html")!
    private let termsURL = URL(string: "https://ozturkozgurm.github.io/overorunder-legal/terms.html")!
    private let feedbackURL = URL(string: "https://ozturkozgurm.github.io/overorunder-legal/feedback.html")!
    
    var body: some View {
        NavigationStack {
            List {
                // 💎 1. ABONELİK DURUMU
                Section(header: Text("Üyelik Bilgileri")) {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isPremiumUser ? Color.blue : (viewModel.isTrialActive ? Color.green : Color.orange))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.isPremiumUser ? viewModel.subscriptionPlanName : (viewModel.isTrialActive ? "Deneme Premium" : "OverOrUnder Pro'ya Geç"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(viewModel.isPremiumUser ? "Aboneliğiniz Aktif" : (viewModel.isTrialActive ? "Kalan Süre: \(viewModel.trialHoursRemaining) Saat" : "Tüm analizlere sınırsız erişin"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // ⚙️ 2. GENEL AYARLAR (Fonksiyonel)
                Section(header: Text("General")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notification", systemImage: "bell.fill")
                    }
                    .tint(.blue)
                    .onChange(of: notificationsEnabled) { oldValue, newValue in
                        handleNotificationToggle(enabled: newValue)
                    }
                    
                    Picker(selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("Türkçe").tag("Turkish")
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    .onChange(of: selectedLanguage) { oldValue, newValue in
                        print("🌐 Dil Değiştirildi: \(newValue)")
                        // Buraya dil değişimini tetikleyen kodunu ekleyebilirsin
                    }
                    
                    Picker(selection: $selectedTheme) {
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                        Text("System").tag("System")
                    } label: {
                        Label("Theme", systemImage: "paintbrush.fill")
                    }
                    .onChange(of: selectedTheme) { oldValue, newValue in
                        print("🎨 Tema Değiştirildi: \(newValue)")
                    }
                }
                
                // ⭐ 3. GERİ BİLDİRİM VE DESTEK (Fonksiyonel)
                Section(header: Text("Feedback & Support")) {
                    Button(action: requestReview) {
                        Label("Rate App", systemImage: "star.fill")
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showFeedback = true }) {
                        Label("Feedback", systemImage: "envelope.fill")
                    }
                    .foregroundColor(.primary)
                }
                
                // ⚖️ 4. YASAL BİLGİLER
                Section(header: Text("Legal")) {
                    Button(action: { showPrivacyPolicy = true }) {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showTerms = true }) {
                        Label("Terms and Conditions", systemImage: "doc.text.fill")
                    }
                    .foregroundColor(.primary)
                }
                
                // ℹ️ 5. HAKKINDA
                Section(header: Text("Hakkında")) {
                    HStack {
                        Label("Versiyon", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0.0").foregroundColor(.gray)
                    }
                    
                    HStack {
                        Label("Kullanıcı ID", systemImage: "person.text.rectangle.fill")
                        Spacer()
                        Text(viewModel.userId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                SubscriptionView(currentSelectedPlanID: viewModel.selectedPlanID)
                    .environmentObject(viewModel)
            }
            .onAppear {
                viewModel.refreshSubscriptionStatus()
            }
            // MARK: - Sheets & Safari
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: privacyURL).ignoresSafeArea()
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: termsURL).ignoresSafeArea()
            }
            .sheet(isPresented: $showFeedback) {
                SafariView(url: feedbackURL).ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Fonksiyonlar
    
    private func handleNotificationToggle(enabled: Bool) {
        if enabled {
            // Bildirim izni iste
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("✅ Bildirim izni verildi.")
                } else if let error = error {
                    print("❌ Bildirim hatası: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.notificationsEnabled = false }
                }
            }
        }
    }
    
    private func requestReview() {
        // Apple'ın değerlendirme popup'ını tetikler (Sınırlı sayıda gösterilir)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}
