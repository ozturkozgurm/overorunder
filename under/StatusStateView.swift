//
//  StatusStateView.swift
//  under
//
//  Created by   Özgür Öztürk on 22.02.2026.
//

import SwiftUI

struct StatusStateView: View {
    enum StateType {
        case noData
        case error
        case loading
    }
    
    let type: StateType
    var retryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Görsel Alanı (SFSymbols ile)
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: iconName)
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, value: type) // iOS 17+ hareketli ikon
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Tekrar Dene Butonu (Sadece hata durumunda)
            if type == .error || type == .noData {
                Button(action: { retryAction?() }) {
                    Label("Yenile", systemImage: "arrow.clockwise")
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Dinamik İçerik Yönetimi
    private var iconName: String {
        switch type {
        case .noData: return "calendar.badge.exclamationmark"
        case .error: return "wifi.exclamationsignal"
        case .loading: return "hourglass"
        }
    }
    
    private var title: String {
        switch type {
        case .noData: return "Maç Bulunamadı"
        case .error: return "Bağlantı Hatası"
        case .loading: return "Analizler Yükleniyor"
        }
    }
    
    private var description: String {
        switch type {
        case .noData: return "Seçtiğiniz tarih için henüz analiz eklenmemiş. Lütfen başka bir günü kontrol edin."
        case .error: return "Veriler alınırken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin."
        case .loading: return "Bugünün en güncel verilerini senin için hazırlıyoruz, lütfen bekle."
        }
    }
}
