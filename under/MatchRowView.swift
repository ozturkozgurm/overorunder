import SwiftUI

struct MatchRowView: View {
    let match: Match
    let hasAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1. LİG İSMİ
            Text(match.eventName)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .center) {
                // 2. TAKIMLAR VE ÖZEL RENKLİ SAAT
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.homeTeam)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(match.awayTeam)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    // 🕒 Açık Mavi Tonlarında Belirgin Saat
                    Text(match.date)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(red: 0.5, green: 0.8, blue: 1.0)) // Açık Mavi (Light Blue)
                        .padding(.top, 2)
                }
                Spacer()
                // 3. KOŞULLU TAHMİN / KİLİT GÖRÜNÜMÜ
                if hasAccess {
                    Text(match.guess.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minWidth: 90)
                        .background(getGuessColor(guess: match.guess).opacity(0.15))
                        .foregroundColor(getGuessColor(guess: match.guess))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(getGuessColor(guess: match.guess).opacity(0.3), lineWidth: 1.5)
                        )
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 14))
                        Text("KİLİTLİ").font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 90, height: 45)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.05)))
    }

    // 🎨 Yeni Renk Şeması: Üst -> Yeşil, Alt -> Kırmızı
    private func getGuessColor(guess: String) -> Color {
        let lowerGuess = guess.lowercased()
        if lowerGuess.contains("üst") {
            return Color.green // 2.5 ÜST için yeşil tonu
        } else if lowerGuess.contains("alt") {
            return Color(red: 1.0, green: 0.3, blue: 0.3) // 2.5 ALT için hafif kırmızı tonu
        } else {
            return .blue // Standart durumlar için
        }
    }
}
