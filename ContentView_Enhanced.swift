import SwiftUI
import CloudKit
import Observation
import AVKit

// MARK: - Design System
struct HealthHubTheme {
    // Enhanced Color Palette
    static let primaryGreen = Color(hex: "2E7D32")      // Deep Forest Green
    static let secondaryGreen = Color(hex: "81C784")    // Soft Sage
    static let tertiaryGreen = Color(hex: "E8F5E9")     // Mint Cream
    static let warningAmber = Color(hex: "FFA726")      // Amber for CTAs
    static let darkGreen = Color(hex: "1B5E20")         // Dark text
    static let backgroundGray = Color(hex: "F8F9FA")    // Light background
    
    // Symptom Colors
    static let respiratory = Color(hex: "4FC3F7")       // Blue-green
    static let pain = Color(hex: "FFB74D")              // Warm orange
    static let digestive = Color(hex: "AED581")         // Yellow-green
    static let mental = Color(hex: "BA68C8")            // Purple-blue
    static let skin = Color(hex: "F48FB1")              // Pink-coral
    static let general = Color(hex: "81C784")           // Default sage
}

// MARK: - Data Model
struct Remedy: Identifiable {
    let id: Int
    let symptom: String
    let title: String
    let description: String
    let videoURL: String
    let featured: Bool
    let approved: Bool
    let dateAdded: Date
    
    init(from record: CKRecord) {
        self.id = record["remedyID"] as? Int ?? 0
        self.symptom = record["symptom"] as? String ?? ""
        self.title = record["title"] as? String ?? ""
        self.description = record["description"] as? String ?? ""
        self.videoURL = record["videoURL"] as? String ?? ""
        self.featured = record["featured"] as? Bool ?? false
        self.approved = record["approved"] as? Bool ?? true
        self.dateAdded = record["dateAdded"] as? Date ?? Date()
    }
    
    init(id: Int, symptom: String, title: String, description: String, videoURL: String) {
        self.id = id
        self.symptom = symptom
        self.title = title
        self.description = description
        self.videoURL = videoURL
        self.featured = false
        self.approved = true
        self.dateAdded = Date()
    }
    
    // Get symptom-specific color
    var symptomColor: Color {
        switch symptom.lowercased() {
        case _ where symptom.contains("cold") || symptom.contains("flu") || symptom.contains("cough"):
            return HealthHubTheme.respiratory
        case _ where symptom.contains("headache") || symptom.contains("pain"):
            return HealthHubTheme.pain
        case _ where symptom.contains("digestive") || symptom.contains("stomach"):
            return HealthHubTheme.digestive
        case _ where symptom.contains("stress") || symptom.contains("anxiety") || symptom.contains("sleep"):
            return HealthHubTheme.mental
        case _ where symptom.contains("skin") || symptom.contains("acne"):
            return HealthHubTheme.skin
        default:
            return HealthHubTheme.general
        }
    }
}

// MARK: - CloudKit Manager (Unchanged for compatibility)
@Observable
class CloudKitManager {
    private let container = CKContainer(identifier: "iCloud.com.yourcompany.HealthHub")
    private let publicDB: CKDatabase
    
    var remedies: [Remedy] = []
    var isLoading = false
    var error: Error?
    
    init() {
        self.publicDB = container.publicCloudDatabase
    }
    
    func fetchRemedies() async {
        isLoading = true
        error = nil
        
        do {
            let predicate = NSPredicate(format: "approved == %@", NSNumber(value: true))
            let query = CKQuery(recordType: "Remedy", predicate: predicate)
            query.sortDescriptors = [
                NSSortDescriptor(key: "featured", ascending: false),
                NSSortDescriptor(key: "dateAdded", ascending: false)
            ]
            
            let results = try await publicDB.records(matching: query)
            
            let fetchedRemedies = results.matchResults.compactMap { result in
                try? result.1.get()
            }.map { Remedy(from: $0) }
            
            await MainActor.run {
                self.remedies = fetchedRemedies
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("Error fetching remedies: \(error)")
            }
        }
    }
    
    func submitRemedy(_ submission: RemedySubmission) async throws {
        let record = CKRecord(recordType: "RemedySubmission")
        record["symptom"] = submission.symptom
        record["title"] = submission.title
        record["description"] = submission.description
        record["submittedBy"] = submission.submittedBy
        record["submittedDate"] = Date()
        record["approved"] = false
        
        try await publicDB.save(record)
    }
}

// MARK: - User Submission Model
struct RemedySubmission {
    var symptom: String = ""
    var title: String = ""
    var description: String = ""
    var submittedBy: String = ""
}

// MARK: - View Model
@Observable
class RemedyViewModel {
    private let cloudKitManager = CloudKitManager()
    
    var remedies: [Remedy] {
        cloudKitManager.remedies
    }
    
    var searchText = ""
    var isSubscribed = false
    var hasCompletedOnboarding = false
    var selectedSymptoms: Set<String> = []
    var isLoading: Bool {
        cloudKitManager.isLoading
    }
    
    var filteredRemedies: [Remedy] {
        var filtered = remedies
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { remedy in
                remedy.symptom.localizedCaseInsensitiveContains(searchText) ||
                remedy.title.localizedCaseInsensitiveContains(searchText) ||
                remedy.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by selected symptoms
        if !selectedSymptoms.isEmpty {
            filtered = filtered.filter { remedy in
                selectedSymptoms.contains { selectedSymptom in
                    remedy.symptom.localizedCaseInsensitiveContains(selectedSymptom)
                }
            }
        }
        
        return filtered
    }
    
    var availableSymptoms: [String] {
        Array(Set(remedies.map(\.symptom))).sorted()
    }
    
    init() {
        Task {
            await loadRemedies()
        }
    }
    
    func loadRemedies() async {
        await cloudKitManager.fetchRemedies()
    }
    
    func refreshRemedies() async {
        await cloudKitManager.fetchRemedies()
    }
    
    func submitRemedy(_ submission: RemedySubmission) async throws {
        try await cloudKitManager.submitRemedy(submission)
    }
    
    func toggleSubscription() {
        withAnimation(.spring()) {
            isSubscribed.toggle()
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Main App View with Tabs
struct ContentView: View {
    @State private var viewModel = RemedyViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        if !viewModel.hasCompletedOnboarding {
            OnboardingFlow(viewModel: viewModel)
        } else {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel)
                    .tabItem {
                        Label("Remedies", systemImage: "leaf.fill")
                    }
                    .tag(0)
                
                SearchView(viewModel: viewModel)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                SavedView(viewModel: viewModel)
                    .tabItem {
                        Label("Saved", systemImage: "bookmark.fill")
                    }
                    .tag(2)
                
                ProfileView(viewModel: viewModel)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(3)
            }
            .tint(HealthHubTheme.primaryGreen)
        }
    }
}

// MARK: - Onboarding Flow
struct OnboardingFlow: View {
    let viewModel: RemedyViewModel
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeView()
                .tag(0)
            
            OnboardingGoalsView(viewModel: viewModel)
                .tag(1)
            
            OnboardingSubscriptionView(viewModel: viewModel)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .background(
            LinearGradient(
                colors: [HealthHubTheme.tertiaryGreen, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct OnboardingWelcomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(HealthHubTheme.primaryGreen)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
            
            VStack(spacing: 16) {
                Text("Welcome to HealthHub")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(HealthHubTheme.darkGreen)
                
                Text("Discover natural remedies\nfor better health")
                    .font(.system(.title2, design: .default))
                    .foregroundColor(HealthHubTheme.darkGreen.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Text("Swipe to continue")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct OnboardingGoalsView: View {
    let viewModel: RemedyViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("What interests you?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundColor(HealthHubTheme.darkGreen)
            
            Text("Select symptoms you'd like to explore")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(["Headache", "Stress", "Cold", "Sleep", "Digestive", "Skin"], id: \.self) { symptom in
                    Button(action: {
                        if viewModel.selectedSymptoms.contains(symptom) {
                            viewModel.selectedSymptoms.remove(symptom)
                        } else {
                            viewModel.selectedSymptoms.insert(symptom)
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.selectedSymptoms.contains(symptom) ? "checkmark.circle.fill" : "circle")
                            Text(symptom)
                        }
                        .foregroundColor(viewModel.selectedSymptoms.contains(symptom) ? .white : HealthHubTheme.primaryGreen)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            viewModel.selectedSymptoms.contains(symptom) ? 
                            HealthHubTheme.primaryGreen : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HealthHubTheme.primaryGreen, lineWidth: 2)
                        )
                        .cornerRadius(12)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingSubscriptionView: View {
    let viewModel: RemedyViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Unlock Premium Content")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundColor(HealthHubTheme.darkGreen)
            
            VStack(spacing: 16) {
                FeatureRow(icon: "play.rectangle.fill", title: "Video Guides", description: "Step-by-step video instructions")
                FeatureRow(icon: "star.fill", title: "Featured Remedies", description: "Curated by health experts")
                FeatureRow(icon: "person.2.fill", title: "Community Access", description: "Connect with others")
            }
            
            Button(action: {
                viewModel.hasCompletedOnboarding = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HealthHubTheme.primaryGreen)
                    .cornerRadius(12)
            }
            
            Button(action: {
                viewModel.hasCompletedOnboarding = true
            }) {
                Text("Maybe Later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(HealthHubTheme.primaryGreen)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(HealthHubTheme.darkGreen)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Bindable var viewModel: RemedyViewModel
    @State private var showingSubmissionForm = false
    @State private var showingSubscriptionAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header
                headerView
                
                if viewModel.isLoading && viewModel.remedies.isEmpty {
                    LoadingView()
                        .frame(maxHeight: .infinity)
                } else {
                    // Remedy List with enhanced cards
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredRemedies) { remedy in
                                NavigationLink(destination: RemedyDetailView(remedy: remedy, viewModel: viewModel)) {
                                    EnhancedRemedyCard(remedy: remedy, isSubscribed: viewModel.isSubscribed)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                    .refreshable {
                        await viewModel.refreshRemedies()
                    }
                }
            }
            .background(HealthHubTheme.backgroundGray)
            .searchable(text: $viewModel.searchText, prompt: "Search symptoms or remedies")
            .navigationTitle("HealthHub")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSubmissionForm = true
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }) {
                        Label("Submit Remedy", systemImage: "plus.circle.fill")
                            .foregroundColor(HealthHubTheme.primaryGreen)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    subscriptionButton
                }
            }
            .sheet(isPresented: $showingSubmissionForm) {
                RemedySubmissionView(viewModel: viewModel)
            }
        }
        .alert("Subscription Required", isPresented: $showingSubscriptionAlert) {
            Button("Subscribe Now") {
                viewModel.toggleSubscription()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unlock video guides and premium content!")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundColor(HealthHubTheme.primaryGreen)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Natural Healing")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(HealthHubTheme.darkGreen)
                    
                    Text("Evidence-based remedies")
                        .font(.system(.caption, design: .default))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Symptom filter chips
            if !viewModel.availableSymptoms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(viewModel.availableSymptoms.prefix(8)), id: \.self) { symptom in
                            SymptomChip(
                                symptom: symptom,
                                isSelected: viewModel.selectedSymptoms.contains(symptom)
                            ) {
                                if viewModel.selectedSymptoms.contains(symptom) {
                                    viewModel.selectedSymptoms.remove(symptom)
                                } else {
                                    viewModel.selectedSymptoms.insert(symptom)
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.white, HealthHubTheme.tertiaryGreen.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var subscriptionButton: some View {
        Button(action: {
            if viewModel.isSubscribed {
                // Already subscribed
            } else {
                showingSubscriptionAlert = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isSubscribed ? "crown.fill" : "crown")
                Text(viewModel.isSubscribed ? "Premium" : "Upgrade")
            }
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundColor(viewModel.isSubscribed ? HealthHubTheme.warningAmber : HealthHubTheme.primaryGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.isSubscribed ? HealthHubTheme.warningAmber.opacity(0.1) : HealthHubTheme.primaryGreen.opacity(0.1))
            )
        }
    }
}

// MARK: - Enhanced Remedy Card
struct EnhancedRemedyCard: View {
    let remedy: Remedy
    let isSubscribed: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced icon with symptom color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [remedy.symptomColor.opacity(0.3), remedy.symptomColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: iconForSymptom(remedy.symptom))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(remedy.symptomColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(remedy.title.capitalized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(HealthHubTheme.darkGreen)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if remedy.featured {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(HealthHubTheme.warningAmber)
                    }
                }
                
                Text("For: \(remedy.symptom)")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
                
                // Premium indicator
                if !isSubscribed {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(HealthHubTheme.warningAmber)
                        Text("Premium video included")
                            .font(.caption2)
                            .foregroundColor(HealthHubTheme.warningAmber)
                    }
                }
            }
            
            // Arrow with animation
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            // Glass morphism effect
            LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [remedy.symptomColor.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(20)
        .shadow(color: HealthHubTheme.primaryGreen.opacity(0.08), radius: 8, x: 0, y: 4)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSubscribed)
    }
    
    private func iconForSymptom(_ symptom: String) -> String {
        switch symptom.lowercased() {
        case _ where symptom.contains("cold") || symptom.contains("flu") || symptom.contains("cough"):
            return "lungs.fill"
        case _ where symptom.contains("headache"):
            return "brain.head.profile"
        case _ where symptom.contains("digestive") || symptom.contains("stomach"):
            return "stomach"
        case _ where symptom.contains("stress") || symptom.contains("anxiety"):
            return "heart.text.square.fill"
        case _ where symptom.contains("sleep"):
            return "moon.fill"
        case _ where symptom.contains("pain"):
            return "figure.walk"
        case _ where symptom.contains("skin"):
            return "hand.raised.fill"
        default:
            return "leaf.fill"
        }
    }
}

// MARK: - Symptom Chip
struct SymptomChip: View {
    let symptom: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(symptom.capitalized)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(isSelected ? .white : HealthHubTheme.primaryGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? HealthHubTheme.primaryGreen : HealthHubTheme.primaryGreen.opacity(0.1))
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Loading View with Skeleton
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding(.horizontal, 20)
    }
}

struct SkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(HealthHubTheme.tertiaryGreen)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(HealthHubTheme.tertiaryGreen)
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                Rectangle()
                    .fill(HealthHubTheme.tertiaryGreen)
                    .frame(height: 12)
                    .frame(maxWidth: 120)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @Bindable var viewModel: RemedyViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("AI-Powered Search")
                    .font(.largeTitle)
                    .padding()
                
                Text("Coming Soon!")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Search")
        }
    }
}

// MARK: - Saved View
struct SavedView: View {
    let viewModel: RemedyViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 60))
                    .foregroundColor(HealthHubTheme.primaryGreen)
                    .padding()
                
                Text("Saved Remedies")
                    .font(.largeTitle)
                    .padding()
                
                Text("Your favorite remedies will appear here")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Saved")
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @Bindable var viewModel: RemedyViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(HealthHubTheme.primaryGreen.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(HealthHubTheme.primaryGreen)
                        )
                    
                    Text("Health Explorer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if viewModel.isSubscribed {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(HealthHubTheme.warningAmber)
                            Text("Premium Member")
                                .foregroundColor(HealthHubTheme.warningAmber)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(HealthHubTheme.warningAmber.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Settings
                VStack(spacing: 0) {
                    SettingsRow(icon: "crown.fill", title: "Subscription", color: HealthHubTheme.warningAmber) {
                        viewModel.toggleSubscription()
                    }
                    
                    Divider().padding(.leading, 50)
                    
                    SettingsRow(icon: "bell.fill", title: "Notifications", color: HealthHubTheme.primaryGreen) {
                        // Handle notifications
                    }
                    
                    Divider().padding(.leading, 50)
                    
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: HealthHubTheme.primaryGreen) {
                        // Handle help
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                
                Spacer()
            }
            .padding()
            .background(HealthHubTheme.backgroundGray)
            .navigationTitle("Profile")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(HealthHubTheme.darkGreen)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Remedy Detail View (Enhanced)
struct RemedyDetailView: View {
    let remedy: Remedy
    @Bindable var viewModel: RemedyViewModel
    @State private var showingVideoAlert = false
    @State private var player: AVPlayer?
    @State private var isShowingVideo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Enhanced Hero Section
                VStack(spacing: 20) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [remedy.symptomColor.opacity(0.3), remedy.symptomColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 60, weight: .medium))
                                .foregroundColor(remedy.symptomColor)
                        )
                        .shadow(color: remedy.symptomColor.opacity(0.2), radius: 20)
                    
                    Text(remedy.title.capitalized)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundColor(HealthHubTheme.darkGreen)
                        .multilineTextAlignment(.center)
                    
                    Label("For \(remedy.symptom)", systemImage: "heart.text.square.fill")
                        .font(.system(.headline, design: .default))
                        .foregroundColor(remedy.symptomColor)
                    
                    if remedy.featured {
                        Label("Featured Remedy", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(HealthHubTheme.warningAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(HealthHubTheme.warningAmber.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                // Description Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("Instructions", systemImage: "list.bullet.rectangle")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(HealthHubTheme.darkGreen)
                    
                    Text(remedy.description)
                        .font(.system(.body, design: .default))
                        .foregroundColor(.secondary)
                        .lineSpacing(8)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal)
                
                // Enhanced Video Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("Video Guide", systemImage: "play.rectangle.fill")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(HealthHubTheme.darkGreen)
                        .padding(.horizontal)
                    
                    ZStack {
                        if viewModel.isSubscribed && isShowingVideo {
                            // Video Player
                            if let player = player {
                                VideoPlayer(player: player)
                                    .frame(height: 250)
                                    .cornerRadius(16)
                                    .onAppear {
                                        player.play()
                                    }
                                    .transition(.opacity.combined(with: .scale))
                            }
                        } else {
                            // Enhanced Premium Lock
                            Button(action: {
                                if viewModel.isSubscribed {
                                    withAnimation(.spring()) {
                                        setupVideoPlayer()
                                        isShowingVideo = true
                                    }
                                } else {
                                    showingVideoAlert = true
                                }
                                
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: viewModel.isSubscribed ? 
                                                [HealthHubTheme.primaryGreen.opacity(0.1), HealthHubTheme.primaryGreen.opacity(0.05)] :
                                                [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 250)
                                    
                                    if !viewModel.isSubscribed {
                                        // Blur effect for non-subscribers
                                        Rectangle()
                                            .fill(Color.white.opacity(0.8))
                                            .blur(radius: 2)
                                            .frame(height: 250)
                                    }
                                    
                                    VStack(spacing: 16) {
                                        Image(systemName: viewModel.isSubscribed ? "play.circle.fill" : "crown.circle.fill")
                                            .font(.system(size: 70, weight: .medium))
                                            .foregroundColor(viewModel.isSubscribed ? HealthHubTheme.primaryGreen : HealthHubTheme.warningAmber)
                                        
                                        VStack(spacing: 8) {
                                            Text(viewModel.isSubscribed ? "Tap to Play Video" : "Premium Content")
                                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                                .foregroundColor(viewModel.isSubscribed ? HealthHubTheme.darkGreen : HealthHubTheme.warningAmber)
                                            
                                            if !viewModel.isSubscribed {
                                                Text("Upgrade to unlock video guides")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isSubscribed)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isShowingVideo)
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added on \(remedy.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 40)
            }
        }
        .background(HealthHubTheme.backgroundGray)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Premium Required", isPresented: $showingVideoAlert) {
            Button("Upgrade Now") {
                viewModel.toggleSubscription()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unlock video guides and premium content with HealthHub Premium!")
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupVideoPlayer() {
        if let url = URL(string: remedy.videoURL) {
            player = AVPlayer(url: url)
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
    }
}

// MARK: - Remedy Submission View (Enhanced)
struct RemedySubmissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var submission = RemedySubmission()
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    let viewModel: RemedyViewModel
    
    let symptomCategories = [
        "Cold & Flu", "Headache", "Digestive Issues", "Skin Conditions",
        "Sleep Problems", "Stress & Anxiety", "Pain Relief", "Allergies", "Other"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Symptom Information") {
                    Picker("Symptom Category", selection: $submission.symptom) {
                        ForEach(symptomCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Remedy Details") {
                    TextField("Remedy Name", text: $submission.title)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $submission.description)
                            .frame(minHeight: 100)
                        
                        if submission.description.isEmpty {
                            Text("Describe how to prepare and use this remedy...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                Section("Your Information") {
                    TextField("Your Name (optional)", text: $submission.submittedBy)
                }
                
                Section {
                    Text("Your submission will be reviewed before being added to HealthHub. Thank you for contributing to our community!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Submit a Remedy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitRemedy()
                    }
                    .disabled(submission.symptom.isEmpty || submission.title.isEmpty || submission.description.isEmpty || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Submitting...")
                                    .font(.headline)
                            }
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                }
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your submission! We'll review it and add it to HealthHub soon.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitRemedy() {
        isSubmitting = true
        
        Task {
            do {
                try await viewModel.submitRemedy(submission)
                await MainActor.run {
                    isSubmitting = false
                    showingSuccessAlert = true
                    
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Color Extension (Enhanced)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}