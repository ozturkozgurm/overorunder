import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MatchViewModel()
    @State private var selectedDate = Date()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showSubscriptionAlert = false
    @State private var showSubscriptionSheet = false
    @State private var isScreenCaptured: Bool = false
    
    // 💡 GÜVENLİK ŞALTERİ: Screenshot engelleyiciyi buradan kontrol edebilirsin.
    @State private var isSecurityEnabled: Bool = false
    
    private func getFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return "\(formatter.string(from: date)).json"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. ÜST BAR
                TopBarView(selectedDate: $selectedDate, onSettingsTap: { showSettings = true })
                Divider()
                
                // 2. TARİH ŞERİDİ
                DateStripView(selectedDate: $selectedDate)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .onChange(of: selectedDate) { _, newValue in
                        viewModel.fetchMatchesFromFirebase(fileName: getFileName(for: newValue))
                    }
                Divider().padding(.top, 10)
                
                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()
                    
                    if viewModel.isLoading {
                        StatusStateView(type: .loading)
                    } else if viewModel.errorMessage != nil {
                        // İnternet hatası vs. varsa
                        StatusStateView(type: .error) {
                            viewModel.refreshData(for: selectedDate)
                        }
                    } else if viewModel.matches.isEmpty {
                        // Veri gerçekten yoksa
                        StatusStateView(type: .noData) {
                            viewModel.refreshData(for: selectedDate)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // 🔥 CANLI SİNYALLER
                                if !viewModel.activeSignals.isEmpty {
                                    ForEach(viewModel.activeSignals) { signal in
                                        conditionalSecurity {
                                            LiveSignalRow(signal: signal, viewModel: viewModel, showSheet: $showSubscriptionSheet)
                                        }
                                        .frame(minHeight: 110).padding(.horizontal)
                                    }
                                }
                                
                                // 🔥 GÜNLÜK MAÇLAR
                                ForEach(viewModel.matches) { match in
                                    let hasAccess = viewModel.canUserSeeMatches(forSelectedDate: selectedDate)
                                    
                                    conditionalSecurity {
                                        MatchRowView(match: match, hasAccess: hasAccess)
                                            .padding()
                                            .background(RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemGroupedBackground))
                                                .shadow(color: .black.opacity(0.04), radius: 3))
                                            .onTapGesture {
                                                if !hasAccess { showSubscriptionAlert = true }
                                            }
                                    }
                                    .frame(minHeight: 100).padding(.horizontal)
                                }
                            }.padding(.vertical, 10)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            // 🛠 TÜM SHEET VE BAĞLANTILAR
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(viewModel)
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView(currentSelectedPlanID: viewModel.selectedPlanID).environmentObject(viewModel)
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingSheetView()
                    .interactiveDismissDisabled()
                    .presentationDetents([.fraction(0.75)])
                    .onDisappear { hasSeenOnboarding = true }
            }
            .alert("Premium Üyelik", isPresented: $showSubscriptionAlert) {
                Button("Üyelik Seçeneklerini Gör") { showSubscriptionSheet = true }
                Button("İptal", role: .cancel) { }
            } message: { Text("Detaylı analizi görmek için premium üye olmanız gerekmektedir.") }
        }
        .overlay(recordingOverlay)
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in updateCaptureStatus() }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
            viewModel.syncWithStoreManager()
            viewModel.fetchMatchesFromFirebase(fileName: getFileName(for: selectedDate))
            updateCaptureStatus()
        }
    }
    
    // MARK: - GÜVENLİK VE YARDIMCI FONKSİYONLAR
    
    @ViewBuilder
    private func conditionalSecurity<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isSecurityEnabled {
            SecurityView { content() }
        } else {
            content()
        }
    }
    
    private var recordingOverlay: some View {
        Group {
            if isScreenCaptured && isSecurityEnabled {
                Color.black.ignoresSafeArea().overlay(Text("Güvenlik: İçerik Gizlendi").foregroundColor(.white))
            }
        }
    }
    
    private func updateCaptureStatus() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene { isScreenCaptured = scene.screen.isCaptured }
    }
}

// MARK: - SecurityView (Screenshot Engelleyici Katman)
struct SecurityView<Content: View>: UIViewRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    func makeUIView(context: Context) -> UIView {
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        let secureView = secureField.layer.sublayers?.first?.delegate as? UIView ?? UIView()
        secureView.subviews.forEach { $0.removeFromSuperview() }
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        secureView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: secureView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: secureView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: secureView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: secureView.trailingAnchor)
        ])
        return secureView
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - LiveSignalRow (Canlı Maç Görünümü)
struct LiveSignalRow: View {
    let signal: Match
    @ObservedObject var viewModel: MatchViewModel
    @Binding var showSheet: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("CANLI ANALİZ").font(.system(size: 10, weight: .black)).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { viewModel.activeSignals.removeAll(where: { $0.id == signal.id }) } }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4))
                }
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("\(signal.homeTeam) vs \(signal.awayTeam)").font(.headline).foregroundColor(.white)
                    Text(signal.date).font(.caption).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                if viewModel.canUserSeeMatches(forSelectedDate: Date()) {
                    Text(signal.guess).bold().padding(8).background(Color.green).foregroundColor(.black).cornerRadius(8)
                } else {
                    Button(action: { showSheet = true }) {
                        Image(systemName: "lock.fill").foregroundColor(.white).padding(10).background(Color.white.opacity(0.2)).clipShape(Circle())
                    }
                }
            }
        }
        .padding().background(Color.blue).cornerRadius(18)
    }
}

// MARK: - DateStripView (Yatay Tarih Şeridi)
struct DateStripView: View {
    @Binding var selectedDate: Date
    @State private var showCalendar = false
    let calendar = Calendar.current
    
    var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. GÜN ŞERİDİ (Eşit Dağıtılmış ve Ortalı)
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { date in
                    VStack(spacing: 6) {
                        Text(getDayName(date))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .blue : .gray)
                            .textCase(.uppercase)
                        
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.blue : Color.clear)
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { selectedDate = date } }
                }
            }
            .padding(.leading, 5) // Sol tarafla denge kurmak için
            
            // 2. ✅ TAKVİM BUTONU (Görseldeki gibi baloncuk açan versiyon)
            Button(action: { showCalendar = true }) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.trailing, 15)
            .popover(isPresented: $showCalendar, arrowEdge: .top) {
                // TAKVİM İÇERİĞİ
                VStack {
                    DatePicker("Tarih Seç", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                }
                .frame(width: 340, height: 380)
                // 🚀 KRİTİK SATIR: iPhone'da tam ekran olmasını engeller, baloncuk yapar.
                .presentationCompactAdaptation(.popover)
                .onChange(of: selectedDate) { _, _ in
                    showCalendar = false
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func getDayName(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "TODAY" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
