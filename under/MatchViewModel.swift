import Foundation
import FirebaseCore
import FirebaseStorage
import FirebaseDatabase
import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    // MARK: - Properties
    @Published var storeManager = StoreManager()
    @Published var matches: [Match] = []
    @Published var isLoading: Bool = false
    @Published var activeSignals: [Match] = []
    @Published var errorMessage: String? = nil
    
    // --- Abonelik Durum Değişkenleri ---
    @Published var isTrialActive: Bool = false
    @Published var trialHoursRemaining: Int = 0
    @Published var isPremiumUser: Bool = false
    @Published var selectedPlanID: String = ""
    @Published var subscriptionPlanName: String = "Ücretsiz Plan"
    @Published var subscriptionDaysRemaining: Int = 0
    @Published var userId: String = "ID-\(Int.random(in: 100000...999999))"
    
    // MARK: - AppStorage (Persistence)
    @AppStorage("isPremium") var isPremium: Bool = false
    @AppStorage("firstLaunchDate") var firstLaunchDate: Date = Date(timeIntervalSince1970: 946684800)
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // MARK: - Private Properties
    private lazy var storage = Storage.storage()
    // ✅ URL ile Manuel Referans: GoogleService-Info.plist hatasını önler
    private let dbBaseRef = Database.database(url: "https://overorunder-7943d-default-rtdb.europe-west1.firebasedatabase.app/").reference()
    private let unlockedMatchesKey = "unlocked_matches_ids"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupInitialState()
        setupStoreManagerObserver()
        setupNotificationObservers()
    }
    
    private func setupInitialState() {
        fetchTodayMatches()
        checkForPendingSignal()
        syncWithStoreManager()
    }
    
    private func setupStoreManagerObserver() {
        storeManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncWithStoreManager()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Subscription Logic
    func syncWithStoreManager() {
        let purchasedIDs = storeManager.purchasedProductIDs
        
        DispatchQueue.main.async {
            if !purchasedIDs.isEmpty || self.isPremium {
                self.isPremiumUser = true
                self.isTrialActive = false
                self.trialHoursRemaining = 0
                
                if let activeID = purchasedIDs.first {
                    self.selectedPlanID = activeID
                    self.updatePlanName(for: activeID)
                }
                print("💎 ABONELİK AKTİF: \(self.selectedPlanID)")
            } else {
                self.isPremiumUser = false
                self.updateTrialStatus()
            }
            self.objectWillChange.send()
        }
    }
    
    private func updatePlanName(for id: String) {
        if id.contains("haftalik") {
            self.subscriptionPlanName = "1 Haftalık Premium"
        } else if id.contains("aylik") {
            self.subscriptionPlanName = "1 Aylık Premium"
        } else if id.contains("yillik") {
            self.subscriptionPlanName = "Yıllık Premium"
        } else {
            self.subscriptionPlanName = "Premium Üye"
        }
    }
    
    private func updateTrialStatus() {
        let trialPeriod: TimeInterval = 3 * 24 * 60 * 60
        let expiryDate = firstLaunchDate.addingTimeInterval(trialPeriod)
        let now = Date()
        
        if firstLaunchDate.timeIntervalSince1970 > 1000000000 && now < expiryDate {
            self.isTrialActive = true
            let diff = expiryDate.timeIntervalSince(now)
            self.trialHoursRemaining = Int(diff / 3600)
            self.subscriptionPlanName = "Deneme Premium"
        } else {
            self.isTrialActive = false
            self.trialHoursRemaining = 0
            self.subscriptionPlanName = "Ücretsiz Plan"
        }
    }
    
    func canUserSeeMatches(forSelectedDate: Date) -> Bool {
        if isPremiumUser || isPremium || isTrialActive { return true }
        return false
    }

    func trialRemainingDays() -> Int {
        let trialPeriod: TimeInterval = 3 * 24 * 60 * 60
        let expiryDate = firstLaunchDate.addingTimeInterval(trialPeriod)
        let remaining = expiryDate.timeIntervalSince(Date())
        return max(0, Int(remaining / (24 * 60 * 60)))
    }
    
    // MARK: - Firebase & Realtime Database Fetching
    
    func fetchMatches(for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy" // Admin panelindeki tireli format
        let dateKey = formatter.string(from: date)
        fetchMatchesFromDatabase(dateKey: dateKey)
    }
    
    func fetchTodayMatches() {
        fetchMatches(for: Date())
    }
    
    /// ✅ GÜNCELLENDİ: Artık Storage'dan değil, Database'den (Node) veri çekiyor.
    func fetchMatchesFromDatabase(dateKey: String) {
        self.isLoading = true
        self.errorMessage = nil
        
        // Admin panelindeki yol: matches -> 24-02-2026
        let matchesRef = dbBaseRef.child("matches").child(dateKey)
        
        matchesRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let value = snapshot.value as? [String: [String: Any]] {
                    // Dictionary yapısını Match modeline çeviriyoruz
                    let decodedMatches = value.values.compactMap { dict -> Match? in
                        return Match(
                            id: dict["id"] as? String ?? UUID().uuidString,
                            eventName: dict["eventName"] as? String ?? "Günün Analizi",
                            date: dict["date"] as? String ?? "", // Maç saati
                            homeTeam: dict["homeTeam"] as? String ?? "",
                            awayTeam: dict["awayTeam"] as? String ?? "",
                            guess: dict["guess"] as? String ?? "",
                            isUnlocked: dict["isUnlocked"] as? Bool ?? false
                        )
                    }
                    
                    self.errorMessage = nil
                    self.matches = decodedMatches.sorted(by: { $0.date < $1.date })
                    // Kilit durumunu dateKey üzerinden senkronize et
                    self.syncUnlockStatus(for: dateKey)
                    print("✅ \(dateKey) verileri başarıyla çekildi.")
                    
                } else {
                    self.matches = []
                    print("ℹ️ \(dateKey) tarihinde veri bulunamadı.")
                }
            }
        }
    }
    
    // MARK: - Locking Mechanism
    private func syncUnlockStatus(for dateKey: String) {
        guard !matches.isEmpty else { return }
        let dateSpecificKey = "unlocked_ids_\(dateKey)"
        let unlockedStringIDs = UserDefaults.standard.stringArray(forKey: dateSpecificKey) ?? []
        var unlockedIDs = Set(unlockedStringIDs)
        
        if unlockedIDs.isEmpty {
            let countToUnlock: Int
            switch matches.count {
            case 5...: countToUnlock = 3
            case 2...4: countToUnlock = 2
            case 1: countToUnlock = 1
            default: countToUnlock = 0
            }
            
            for i in 0..<min(countToUnlock, matches.count) {
                unlockedIDs.insert(matches[i].id)
            }
            UserDefaults.standard.set(Array(unlockedIDs), forKey: dateSpecificKey)
        }
        
        let globalUnlockedIDs = Set(UserDefaults.standard.stringArray(forKey: unlockedMatchesKey) ?? [])
        
        for i in 0..<matches.count {
            self.matches[i].isUnlocked = unlockedIDs.contains(matches[i].id) || globalUnlockedIDs.contains(matches[i].id)
        }
        self.objectWillChange.send()
    }
    
    func saveUnlockedMatch(id: String, dateKey: String) {
        let dateSpecificKey = "unlocked_ids_\(dateKey)"
        var dailyIDs = Set(UserDefaults.standard.stringArray(forKey: dateSpecificKey) ?? [])
        dailyIDs.insert(id)
        UserDefaults.standard.set(Array(dailyIDs), forKey: dateSpecificKey)
        
        if let index = matches.firstIndex(where: { $0.id == id }) {
            DispatchQueue.main.async {
                self.matches[index].isUnlocked = true
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Notification & Signal Handling
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("LiveSignalReceived"), object: nil, queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo { self?.handleLiveNotification(userInfo: userInfo) }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PremiumStatusChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.syncWithStoreManager()
        }
    }
    
    func handleLiveNotification(userInfo: [AnyHashable: Any]) {
        guard let home = userInfo["homeTeam"] as? String,
              let away = userInfo["awayTeam"] as? String,
              let pred = userInfo["prediction"] as? String else { return }
            
        let newSignal = Match(
            id: userInfo["matchID"] as? String ?? UUID().uuidString,
            eventName: "Canlı Analiz",
            date: "Dakika: \(userInfo["minute"] ?? "1'")",
            homeTeam: home,
            awayTeam: away,
            guess: pred,
            isUnlocked: true
        )
        
        DispatchQueue.main.async {
            withAnimation(.spring()) {
                if !self.activeSignals.contains(where: { $0.id == newSignal.id }) {
                    self.activeSignals.insert(newSignal, at: 0)
                }
            }
        }
    }
    
    func checkForPendingSignal() {
        guard let home = UserDefaults.standard.string(forKey: "pendingHome"),
              let away = UserDefaults.standard.string(forKey: "pendingAway"),
              let pred = UserDefaults.standard.string(forKey: "pendingPred") else { return }
        
        let minute = UserDefaults.standard.string(forKey: "pendingMinute") ?? "1'"
        let signal = Match(id: UUID().uuidString, eventName: "Canlı Analiz", date: "Dakika: \(minute)", homeTeam: home, awayTeam: away, guess: pred, isUnlocked: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring()) {
                if !self.activeSignals.contains(where: { $0.id == signal.id }) {
                    self.activeSignals.insert(signal, at: 0)
                }
            }
            UserDefaults.standard.removeObject(forKey: "pendingHome")
        }
    }
    
    // MARK: - Public Utility Methods
    func forceSyncAfterPurchase() {
        syncWithStoreManager()
        print("🔄 [MANUEL SENKRONİZASYON] Satın alma sonrası tetiklendi.")
    }
    
    func refreshSubscriptionStatus() {
        syncWithStoreManager()
    }
    
    func refreshData(for date: Date) {
        fetchMatches(for: date)
    }
    
    func recordSuccessfulPayment(planID: String, amount: Double) {
        // ✅ DÜZELTME: dbBaseRef üzerinden Realtime Database'e kayıt
        let paymentRef = dbBaseRef.child("payments").childByAutoId()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        
        let paymentData: [String: Any] = [
            "planID": planID,
            "amount": amount,
            "date": formatter.string(from: Date()),
            "timestamp": ServerValue.timestamp(),
            "userId": self.userId
        ]
        
        paymentRef.setValue(paymentData) { error, _ in
            if let error = error {
                print("❌ Ödeme kaydı hatası: \(error.localizedDescription)")
            } else {
                print("✅ Ödeme admin paneline başarıyla düştü.")
            }
        }
    }
}
