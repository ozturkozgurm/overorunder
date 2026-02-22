import SwiftUI
import UserNotifications

struct OnboardingSheetView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var selectedLanguage = "English"
    let totalSteps = 3
    
    var body: some View {
        ZStack {
            // Arka Plan (Derin Lacivert/Siyah Tonu)
            Color(red: 0.05, green: 0.07, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Adım Göstergesi (Progress Bar)
                stepIndicator
                
                Spacer()
                
                // 2. İçerik Alanı (Animasyonlu Geçişler)
                contentView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
                Spacer()
                
                // 3. Aksiyon Butonları
                actionButtons
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.white : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.spring(), value: currentStep)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 25)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch currentStep {
        case 0: LanguageSelectionView(selectedLanguage: $selectedLanguage)
        case 1: NotificationPromptView()
        case 2: WelcomeGiftView()
        default: EmptyView()
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: nextStep) {
                Text(currentStep == 2 ? "Hemen Başla" : "Devam Et")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(currentStep == 2 ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(currentStep == 2 ? Color.green : Color.blue)
                    .cornerRadius(16)
                    .shadow(color: (currentStep == 2 ? Color.green : Color.blue).opacity(0.3), radius: 10, y: 5)
            }
            
            if currentStep == 1 {
                Button("Belki Daha Sonra") {
                    nextStep()
                }
                .foregroundColor(.gray)
                .font(.subheadline)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // MARK: - Functions
    
    func nextStep() {
        if currentStep == 1 {
            requestNotificationPermission()
        }
        
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            // Onboarding tamamlandı şalterini indir
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            dismiss()
        }
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { print("✅ Onboarding: Bildirim izni verildi.") }
        }
    }
}

// MARK: - 1. ADIM: Dil Seçimi
struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String
    let languages = [
        ("English", "🇺🇸"), ("Türkçe", "🇹🇷"), ("Deutsch", "🇩🇪"),
        ("Français", "🇫🇷"), ("Español", "🇪🇸"), ("Italiano", "🇮🇹")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Dil Seçin")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Size daha iyi hizmet verebilmemiz için bir dil seçin.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(languages, id: \.0) { lang in
                        HStack {
                            Text(lang.1)
                            Text(lang.0)
                                .fontWeight(selectedLanguage == lang.0 ? .bold : .regular)
                            Spacer()
                            if selectedLanguage == lang.0 {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .background(Color.white.opacity(selectedLanguage == lang.0 ? 0.1 : 0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedLanguage == lang.0 ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedLanguage = lang.0 }
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - 2. ADIM: Bildirim İzni
struct NotificationPromptView: View {
    var body: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 140, height: 140)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .shadow(color: .blue.opacity(0.4), radius: 15)
            }
            
            VStack(spacing: 12) {
                Text("Güncel Kalın")
                    .font(.title).fontWeight(.bold).foregroundColor(.white)
                
                Text("Önemli maç tahminleri ve anlık analizlerden ilk siz haberdar olun.")
                    .font(.body).multilineTextAlignment(.center)
                    .foregroundColor(.gray).padding(.horizontal, 30)
            }
        }
    }
}

// MARK: - 3. ADIM: Hoş Geldin Hediyesi
struct WelcomeGiftView: View {
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 1).frame(width: 200, height: 200)
                
                VStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 60)).foregroundColor(.green)
                        .shadow(color: .green.opacity(0.3), radius: 10)
                    
                    Text("İLK 3 GÜN")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ÜCRETSİZ ERİŞİM")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green).foregroundColor(.black).cornerRadius(8)
                }
            }
            
            VStack(spacing: 12) {
                Text("Hoş Geldiniz!")
                    .font(.title).fontWeight(.bold).foregroundColor(.white)
                
                Text("Uygulamayı indirdiğiniz ilk 3 gün boyunca tüm analizler size özel tamamen açık ve ücretsizdir.")
                    .font(.body).multilineTextAlignment(.center)
                    .foregroundColor(.gray).padding(.horizontal, 30)
            }
        }
    }
}
