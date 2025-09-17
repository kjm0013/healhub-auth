import SwiftUI
import StoreKit
import AuthenticationServices
import CloudKit

// MARK: - Authentication Manager
@Observable
class AuthenticationManager {
    var isAuthenticated = false
    var user: User?
    var authToken: String?
    
    private let baseURL = "http://localhost:3001/api" // Change to your server URL
    
    init() {
        loadStoredAuth()
    }
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    func authenticateWithReceipt() async {
        guard let receiptData = getReceiptData() else {
            print("No receipt data available")
            return
        }
        
        // If we have stored Apple credentials, use them
        if let appleUserId = getStoredAppleUserId(),
           let email = getStoredEmail() {
            await sendAuthToServer(
                appleUserId: appleUserId,
                email: email,
                receiptData: receiptData
            )
        }
    }
    
    private func sendAuthToServer(appleUserId: String, email: String, receiptData: String) async {
        do {
            let url = URL(string: "\(baseURL)/auth/apple")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = [
                "appleUserId": appleUserId,
                "email": email,
                "receiptData": receiptData
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            await MainActor.run {
                if response.success {
                    self.authToken = response.token
                    self.user = response.user
                    self.isAuthenticated = true
                    self.saveAuthData()
                }
            }
        } catch {
            print("Auth error: \(error)")
        }
    }
    
    private func getReceiptData() -> String? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return nil
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL)
            return receiptData.base64EncodedString()
        } catch {
            print("Receipt error: \(error)")
            return nil
        }
    }
    
    private func saveAuthData() {
        UserDefaults.standard.set(authToken, forKey: "auth_token")
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "user_data")
        }
    }
    
    private func loadStoredAuth() {
        authToken = UserDefaults.standard.string(forKey: "auth_token")
        if let userData = UserDefaults.standard.data(forKey: "user_data"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.user = user
            self.isAuthenticated = authToken != nil
        }
    }
    
    private func getStoredAppleUserId() -> String? {
        return UserDefaults.standard.string(forKey: "apple_user_id")
    }
    
    private func getStoredEmail() -> String? {
        return UserDefaults.standard.string(forKey: "user_email")
    }
    
    func logout() {
        isAuthenticated = false
        user = nil
        authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "user_data")
    }
}

// MARK: - Apple Sign In Delegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let appleUserId = appleIDCredential.user
            let email = appleIDCredential.email ?? getStoredEmail() ?? ""
            
            // Store credentials
            UserDefaults.standard.set(appleUserId, forKey: "apple_user_id")
            if let email = appleIDCredential.email {
                UserDefaults.standard.set(email, forKey: "user_email")
            }
            
            Task {
                if let receiptData = getReceiptData() {
                    await sendAuthToServer(
                        appleUserId: appleUserId,
                        email: email,
                        receiptData: receiptData
                    )
                } else {
                    await sendAuthToServer(
                        appleUserId: appleUserId,
                        email: email,
                        receiptData: ""
                    )
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In error: \(error)")
    }
}

// MARK: - Subscription Manager
@Observable
class SubscriptionManager {
    var isSubscribed = false
    var subscriptionStatus: SubscriptionStatus?
    
    private let authManager: AuthenticationManager
    private let baseURL = "http://localhost:3001/api"
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    func checkSubscriptionStatus() async {
        guard let token = authManager.authToken else { return }
        
        do {
            let url = URL(string: "\(baseURL)/subscription/status")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
            
            await MainActor.run {
                self.isSubscribed = response.isActive
                self.subscriptionStatus = response.subscription
            }
        } catch {
            print("Subscription check error: \(error)")
        }
    }
    
    func handlePurchaseCompletion() async {
        // After a successful purchase, authenticate with receipt
        await authManager.authenticateWithReceipt()
        await checkSubscriptionStatus()
    }
}

// MARK: - Data Models
struct User: Codable {
    let id: Int
    let email: String
    let appleUserId: String?
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String
    let user: User
}

struct SubscriptionStatus: Codable {
    let productId: String?
    let expiresAt: String?
}

struct SubscriptionStatusResponse: Codable {
    let isActive: Bool
    let subscription: SubscriptionStatus?
}

// MARK: - Updated View Model Integration
extension RemedyViewModel {
    var authManager: AuthenticationManager {
        // Add this property to your existing RemedyViewModel
        return AuthenticationManager.shared // Implement singleton pattern
    }
    
    var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(authManager: authManager)
    }
    
    func updateSubscriptionStatus() {
        Task {
            await subscriptionManager.checkSubscriptionStatus()
            await MainActor.run {
                self.isSubscribed = subscriptionManager.isSubscribed
            }
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    @Bindable var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(HealthHubTheme.primaryGreen)
                
                Text("Access Your Account")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Sign in to sync your subscription across devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            SignInWithAppleButton(.signIn) { request in
                authManager.signInWithApple()
            } onCompletion: { result in
                // Handled in AuthenticationManager delegate
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
            
            Text("Your subscription will be validated automatically")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
    }
}

// MARK: - Integration with Main App
extension ContentView {
    var authenticationOverlay: some View {
        Group {
            if !viewModel.authManager.isAuthenticated {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        AuthenticationView(authManager: viewModel.authManager)
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(20)
                    }
            }
        }
    }
}

// Usage in your main ContentView:
// Add .overlay(authenticationOverlay) to your main view