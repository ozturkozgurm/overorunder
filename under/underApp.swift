import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - AppDelegate (Firebase & Notifications)
class MyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        checkFirstLaunchDate()
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        application.registerForRemoteNotifications()
        return true
    }
    
    private func checkFirstLaunchDate() {
        // Eğer daha önce kaydedilmemişse (İlk kurulum anı)
        if UserDefaults.standard.object(forKey: "firstLaunchDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "firstLaunchDate")
            print("🚀 İlk açılış tarihi şu an olarak kaydedildi.")
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🎫 FCM Kayıt Tokenı: \(String(describing: fcmToken))")
        
        // Tüm kullanıcılara genel bildirim göndermek için kanal aboneliği
        Messaging.messaging().subscribe(toTopic: "all_users") { error in
            if let error = error {
                print("❌ 'all_users' kanalına abone olunamadı: \(error.localizedDescription)")
            } else {
                print("✅ 'all_users' kanalına abone olundu.")
            }
        }
    }
    
    // Uygulama ön plandayken bildirim gelirse
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Bildirime tıklandığında
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 1. Uygulama açıkken anlık sinyali gönder
        NotificationCenter.default.post(name: NSNotification.Name("LiveSignalReceived"), object: nil, userInfo: userInfo)
        
        // 2. Uygulama kapalıysa veriyi UserDefaults'a yaz (ViewModel init'te kontrol edecek)
        if let home = userInfo["homeTeam"] as? String,
           let away = userInfo["awayTeam"] as? String,
           let pred = userInfo["prediction"] as? String {
            
            let defaults = UserDefaults.standard
            defaults.set(home, forKey: "pendingHome")
            defaults.set(away, forKey: "pendingAway")
            defaults.set(pred, forKey: "pendingPred")
            defaults.set(userInfo["minute"] as? String ?? "1'", forKey: "pendingMinute")
        }
        
        completionHandler()
    }
}

// MARK: - Main Application
@main
struct underApp: App {
    @UIApplicationDelegateAdaptor(MyAppDelegate.self) var delegate
    
    // Merkezi veri yönetimi
    @StateObject private var viewModel = MatchViewModel()
    @State private var isActive = false
    @State private var showSubscriptionSheet = false
    
    var body: some Scene {
        WindowGroup {
            if isActive {
                ContentView()
                    .environmentObject(viewModel)
                    .onAppear {
                        // Uygulama açıldığında abonelik durumunu tazele
                        Task {
                            await viewModel.storeManager.updatePurchasedProducts()
                            viewModel.syncWithStoreManager()
                        }
                    }
                    // Abonelik Bitiş Uyarısı
                    .alert("Premium Üyeliğiniz Sona Erdi", isPresented: $viewModel.storeManager.showExpirationAlert) {
                        Button("Planları İncele") { showSubscriptionSheet = true }
                        Button("Kapat", role: .cancel) { }
                    } message: {
                        Text("Analiz ve tahminlere kesintisiz erişim sağlamak için üyeliğinizi yenileyebilirsiniz.")
                    }
                    // Abonelik Sayfası (Sheet)
                    .sheet(isPresented: $showSubscriptionSheet) {
                        SubscriptionView(currentSelectedPlanID: viewModel.selectedPlanID)
                            .environmentObject(viewModel)
                    }
            } else {
                SplashView()
                    .onAppear {
                        // 3 saniyelik Splash süresi
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                self.isActive = true
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - SplashView
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("maradona") // Assets'te mevcut olmalı
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(color: .white.opacity(0.15), radius: 15)
                
                VStack(spacing: 10) {
                    Text("OverOrUnder")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(8)
                    
                    Text("GÜNCEL TAHMİNLER")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .tracking(3)
                }
                
                ProgressView()
                    .tint(.white)
                    .padding(.top, 30)
            }
        }
    }
}
