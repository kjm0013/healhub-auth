import SwiftUI
import CloudKit
import Observation
import AVKit

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
}

// MARK: - CloudKit Manager
@Observable
class CloudKitManager {
    private let container = CKContainer(identifier: "iCloud.com.yourcompany.HealHub")
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
    var isLoading: Bool {
        cloudKitManager.isLoading
    }
    
    var filteredRemedies: [Remedy] {
        if searchText.isEmpty {
            return remedies
        } else {
            return remedies.filter { remedy in
                remedy.symptom.localizedCaseInsensitiveContains(searchText) ||
                remedy.title.localizedCaseInsensitiveContains(searchText) ||
                remedy.description.localizedCaseInsensitiveContains(searchText)
            }
        }
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
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var viewModel = RemedyViewModel()
    @State private var showingSubscriptionAlert = false
    @State private var showingSubmissionForm = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                if viewModel.isLoading && viewModel.remedies.isEmpty {
                    ProgressView("Loading remedies...")
                        .frame(maxHeight: .infinity)
                } else {
                    // Remedy List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredRemedies) { remedy in
                                NavigationLink(destination: RemedyDetailView(remedy: remedy, viewModel: viewModel)) {
                                    RemedyRowView(remedy: remedy)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .refreshable {
                        await viewModel.refreshRemedies()
                    }
                }
            }
            .background(Color.white)
            .searchable(text: $viewModel.searchText, prompt: "Search symptoms or remedies")
            .navigationTitle("HealHub")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSubmissionForm = true
                    }) {
                        Label("Submit Remedy", systemImage: "plus.circle")
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
        .tint(Color(hex: "4CAF50"))
        .alert("Subscription Required", isPresented: $showingSubscriptionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Subscribe to unlock video content and premium features!")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "4CAF50"))
            
            Text("Natural Home Remedies")
                .font(.system(.headline, design: .default))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
    }
    
    private var subscriptionButton: some View {
        Button(action: {
            showingSubscriptionAlert = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isSubscribed ? "star.fill" : "star")
                Text(viewModel.isSubscribed ? "Premium" : "Subscribe")
            }
            .font(.system(.body, design: .default).weight(.medium))
            .foregroundColor(Color(hex: "4CAF50"))
        }
    }
}

// MARK: - Remedy Submission View
struct RemedySubmissionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var submission = RemedySubmission()
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    let viewModel: RemedyViewModel
    
    let symptomCategories = [
        "Cold & Flu",
        "Headache",
        "Digestive Issues",
        "Skin Conditions",
        "Sleep Problems",
        "Stress & Anxiety",
        "Pain Relief",
        "Allergies",
        "Other"
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
                    
                    TextEditor(text: $submission.description)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
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
                    Text("Your submission will be reviewed before being added to HealHub. We appreciate your contribution to our community!")
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
                            ProgressView("Submitting...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                }
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your submission! We'll review it and add it to HealHub soon.")
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
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Remedy Row View
struct RemedyRowView: View {
    let remedy: Remedy
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color(hex: "4CAF50").opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: iconForSymptom(remedy.symptom))
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "4CAF50"))
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(remedy.title.capitalized)
                        .font(.system(.headline, design: .default))
                        .foregroundColor(.primary)
                    
                    if remedy.featured {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "4CAF50"))
                    }
                }
                
                Text("For: \(remedy.symptom)")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func iconForSymptom(_ symptom: String) -> String {
        switch symptom.lowercased() {
        case _ where symptom.contains("cold") || symptom.contains("flu"):
            return "lungs.fill"
        case _ where symptom.contains("headache"):
            return "brain.head.profile"
        case _ where symptom.contains("digestive"):
            return "stomach"
        case _ where symptom.contains("skin"):
            return "hand.raised.fill"
        case _ where symptom.contains("sleep"):
            return "moon.fill"
        case _ where symptom.contains("stress") || symptom.contains("anxiety"):
            return "heart.text.square.fill"
        case _ where symptom.contains("pain"):
            return "figure.walk"
        case _ where symptom.contains("allergies"):
            return "allergens"
        default:
            return "leaf.fill"
        }
    }
}

// MARK: - Remedy Detail View
struct RemedyDetailView: View {
    let remedy: Remedy
    let viewModel: RemedyViewModel
    @State private var showingVideoAlert = false
    @State private var player: AVPlayer?
    @State private var isShowingVideo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Section
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: "4CAF50").opacity(0.1))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "4CAF50"))
                        )
                    
                    Text(remedy.title.capitalized)
                        .font(.system(.largeTitle, design: .default).weight(.bold))
                        .multilineTextAlignment(.center)
                    
                    Label("For \(remedy.symptom)", systemImage: "heart.text.square.fill")
                        .font(.system(.headline, design: .default))
                        .foregroundColor(Color(hex: "4CAF50"))
                    
                    if remedy.featured {
                        Label("Featured Remedy", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "4CAF50"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: "4CAF50").opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                // Description Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("Instructions", systemImage: "list.bullet.rectangle")
                        .font(.system(.title2, design: .default).weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(remedy.description)
                        .font(.system(.body, design: .default))
                        .foregroundColor(.secondary)
                        .lineSpacing(8)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal)
                
                // Video Section
                VStack(alignment: .leading, spacing: 16) {
                    Label("Video Guide", systemImage: "play.rectangle.fill")
                        .font(.system(.title2, design: .default).weight(.semibold))
                        .foregroundColor(.primary)
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
                            // Subscription Lock / Play Button
                            Button(action: {
                                if viewModel.isSubscribed {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        setupVideoPlayer()
                                        isShowingVideo = true
                                    }
                                } else {
                                    showingVideoAlert = true
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 250)
                                    
                                    VStack(spacing: 12) {
                                        Image(systemName: viewModel.isSubscribed ? "play.circle.fill" : "lock.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(viewModel.isSubscribed ? Color(hex: "4CAF50") : .gray)
                                        
                                        Text(viewModel.isSubscribed ? "Tap to Play Video" : "Subscribe to Unlock")
                                            .font(.system(.headline, design: .default))
                                            .foregroundColor(viewModel.isSubscribed ? .primary : .secondary)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSubscribed)
                    .animation(.easeInOut(duration: 0.3), value: isShowingVideo)
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
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Subscription Required", isPresented: $showingVideoAlert) {
            Button("Subscribe Now") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.isSubscribed = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unlock video guides and premium content with a HealHub subscription!")
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupVideoPlayer() {
        if let url = URL(string: remedy.videoURL) {
            player = AVPlayer(url: url)
            
            // Set up notification for video end to loop
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

// MARK: - Color Extension
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