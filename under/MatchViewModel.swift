import Foundation
import FirebaseCore
import FirebaseStorage
import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    // MARK: - Properties
    @Published var storeManager = StoreManager()
    @Published var matches: [Match] = []
    @Published var isLoading: Bool = false
    @Published var activeSignals: [Match] = []
    @Published var errorMessage: String? = nil // ✅ Yeni: Hata takibi için
    
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
    
    // MARK: - Firebase & Data Fetching
    
    // ✅ Yeni: Takvimden seçilen tarihe göre veri çekmek için
    func fetchMatches(for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let fileName = "\(formatter.string(from: date)).json"
        fetchMatchesFromFirebase(fileName: fileName)
    }
    
    func fetchTodayMatches() {
        fetchMatches(for: Date())
    }
    
    func fetchMatchesFromFirebase(fileName: String) {
        self.isLoading = true
        self.errorMessage = nil // Yeni bir istek başlarken hatayı sıfırla
        
        let storageRef = storage.reference(forURL: "gs://overorunder-7943d.firebasestorage.app/\(fileName)")
        
        storageRef.getData(maxSize: 1 * 1024 * 1024) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Firebase Hatası: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.matches = []
                    self.errorMessage = error.localizedDescription // ✅ Yeni: Hata mesajını kaydet
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([Match].self, from: data)
                DispatchQueue.main.async {
                    self.errorMessage = nil // Başarılıysa hatayı temizle
                    self.matches = decodedData
                    self.syncUnlockStatus(for: fileName)
                    self.isLoading = false
                }
            } catch {
                print("Decode Hatası: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Veri formatı hatalı."
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Locking Mechanism
    private func syncUnlockStatus(for fileName: String) {
        guard !matches.isEmpty else { return }
        let dateSpecificKey = "unlocked_ids_\(fileName)"
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
            
            for i in 0..<countToUnlock {
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
    
    func saveUnlockedMatch(id: String, fileName: String) {
        let dateSpecificKey = "unlocked_ids_\(fileName)"
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
    
    // ✅ Yeni: Yenileme butonu için
    func refreshData(for date: Date) {
        fetchMatches(for: date)
    }
}
