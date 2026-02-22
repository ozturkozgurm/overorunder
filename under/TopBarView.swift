import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var viewModel: MatchViewModel
    // ✅ selectedDate Binding'ini koruyoruz çünkü TopBar'ın bu bilgiye
    // hala ContentView üzerinden ihtiyacı olabilir (Data akışı için)
    @Binding var selectedDate: Date
    var onSettingsTap: () -> Void
    
    var body: some View {
        ZStack {
            // 1. MERKEZDEKİ LOGO
            logoView
            
            // 2. SAĞ VE SOL ELEMENTLER
            HStack {
                // SOLDAKİ DURUM GÖSTERGESİ (PRO/TRIAL/FREE)
                statusIndicator
                
                Spacer()
                
                // SAĞDAKİ AYARLAR BUTONU
                // Artık burada sadece Ayarlar var, Takvim aşağıda (DateStripView içinde)
                Button(action: onSettingsTap) {
                    Image(systemName: "line.3.horizontal.circle.fill")
                        .font(.system(size: 26))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Logo Bileşeni
    private var logoView: some View {
        HStack(spacing: 4) {
            Text("OVER").font(.system(size: 20, weight: .black, design: .rounded))
            Text("/").font(.system(size: 20, weight: .black)).foregroundColor(.gray.opacity(0.5))
            Text("UNDER").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.blue)
        }
    }
    
    // MARK: - Durum Göstergesi (Kapsül)
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.isPremiumUser ? "crown.fill" : (viewModel.isTrialActive ? "bolt.fill" : "star.fill"))
                .foregroundColor(viewModel.isPremiumUser ? .blue : (viewModel.isTrialActive ? .green : .orange))
                .font(.system(size: 12))
            
            Text(viewModel.isPremiumUser ? "PRO" : (viewModel.isTrialActive ? "TRIAL" : "FREE"))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
    }
}
