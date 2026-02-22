//
//  Match.swift
//  under
//
//  Created by   Özgür Öztürk on 7.02.2026.
//


import Foundation

// Her bir maç tahminini temsil eden model
struct Match: Identifiable, Codable {
    let id: String
    let eventName: String
    let date: String
    let homeTeam: String
    let awayTeam: String
    let guess: String
    
    // isUnlocked alanını 'var' yapıyoruz ve CodingKeys dışında tutuyoruz
    var isUnlocked: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, eventName, date, homeTeam, awayTeam, guess
        // isUnlocked BURADA OLMAMALI (Çünkü JSON'dan değil, bizden geliyor)
    }
}
