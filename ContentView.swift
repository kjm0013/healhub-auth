import SwiftUI
import Observation
import AVKit

// MARK: - Data Model
struct Remedy: Identifiable, Codable {
    let id: Int
    let symptom: String
    let title: String
    let description: String
    let video: String
}

struct RemediesData: Codable {
    let remedies: [Remedy]
}

// MARK: - View Model
@Observable
class RemedyViewModel {
    var remedies: [Remedy] = []
    var searchText = ""
    var isSubscribed = false
    
    var filteredRemedies: [Remedy] {
        if searchText.isEmpty {
            return remedies
        } else {
            return remedies.filter { remedy in
                remedy.symptom.localizedCaseInsensitiveContains(searchText) ||
                remedy.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    init() {
        loadRemedies()
    }
    
    private func loadRemedies() {
        // Sample data - in production, this would load from a file or API
        let jsonData = """
        {
          "remedies": [
            {"id": 1, "symptom": "sore throat", "title": "ginger tea", "description": "Boil 1 tsp ginger in 1 cup water for 10 minutes...", "video": "https://yourserver.com/gingertea.mp4"},
            {"id": 2, "symptom": "flu", "title": "honey", "description": "Mix 1 tbsp honey with warm water...", "video": "https://yourserver.com/honey.mp4"},
            {"id": 3, "symptom": "cold", "title": "coconut oil", "description": "Take 1 tsp orally...", "video": "https://yourserver.com/coconutoil.mp4"},
            {"id": 4, "symptom": "headache", "title": "compress", "description": "Apply a cold compress for 15 minutes...", "video": "https://yourserver.com/compress.mp4"},
            {"id": 5, "symptom": "tension", "title": "peppermint oil", "description": "Rub on temples...", "video": "https://yourserver.com/peppermintoil.mp4"},
            {"id": 6, "symptom": "joint pain", "title": "lemon", "description": "Drink with warm water...", "video": "https://yourserver.com/lemon.mp4"},
            {"id": 7, "symptom": "acid reflux", "title": "turmeric", "description": "Mix 1 tsp with milk...", "video": "https://yourserver.com/turmeric.mp4"},
            {"id": 8, "symptom": "eye strain", "title": "black pepper", "description": "Use in a warm compress...", "video": "https://yourserver.com/blackpepper.mp4"},
            {"id": 9, "symptom": "congestion", "title": "apple cider vinegar", "description": "Dilute 1 tbsp in water...", "video": "https://yourserver.com/applecidervinegar.mp4"},
            {"id": 10, "symptom": "sunburn", "title": "vinegar", "description": "Apply diluted vinegar...", "video": "https://yourserver.com/vinegar.mp4"}
          ]
        }
        """.data(using: .utf8)!
        
        do {
            let decodedData = try JSONDecoder().decode(RemediesData.self, from: jsonData)
            self.remedies = decodedData.remedies
        } catch {
            print("Error decoding remedies: \(error)")
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var viewModel = RemedyViewModel()
    @State private var showingSubscriptionAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
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
            }
            .background(Color.white)
            .searchable(text: $viewModel.searchText, prompt: "Search symptoms or remedies")
            .navigationTitle("HealHub")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    subscriptionButton
                }
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
                Text(remedy.title.capitalized)
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.primary)
                
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
        case "sore throat", "flu", "cold", "congestion":
            return "lungs.fill"
        case "headache", "tension":
            return "brain.head.profile"
        case "joint pain":
            return "figure.walk"
        case "acid reflux":
            return "flame.fill"
        case "eye strain":
            return "eye.fill"
        case "sunburn":
            return "sun.max.fill"
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
        // Use video URL from remedy, fallback to placeholder if needed
        let videoURLString = remedy.video.isEmpty ? "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" : remedy.video
        
        if let url = URL(string: videoURLString) {
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