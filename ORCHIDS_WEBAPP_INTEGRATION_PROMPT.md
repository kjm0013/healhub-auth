# 🍎 HealthHub Webapp Authentication Integration - Orchids Prompt

## Context
I have a complete iOS app authentication system and need to integrate cross-platform login into my existing webapp at https://home-remedy-hub.vercel.app. Users purchase subscriptions only through the iOS app, then use Apple Sign In to unlock premium content on the web.

## Integration Requirements

### 1. Add Apple Sign In Web SDK
Add to your HTML `<head>`:
```html
<script src="https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"></script>
```

### 2. Authentication Section HTML
Add this auth header to your webapp:
```html
<div class="auth-section" style="display: flex; align-items: center; gap: 12px; padding: 12px 0;">
  <div class="user-profile" style="display: none;"></div>
  
  <button class="apple-signin-btn login-button" style="
    background: #000;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 8px;
    font-weight: 500;
    cursor: pointer;
  ">
    🍎 Sign in with Apple
  </button>
  
  <button class="logout-btn logout-button" style="
    background: #666;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    display: none;
  ">
    Logout
  </button>
</div>

<div class="subscription-status" style="
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 14px;
  margin: 10px 0;
"></div>
```

### 3. Premium Content Gating
Wrap your premium content (videos, detailed remedies) like this:
```html
<div class="remedy-content">
  <!-- Premium content (videos, detailed instructions) -->
  <div class="premium-content" style="display: none;">
    [Your actual premium content here]
  </div>
  
  <!-- Content locked message -->
  <div class="content-locked">
    <div style="
      background: rgba(0,0,0,0.1);
      padding: 40px;
      text-align: center;
      border-radius: 12px;
      border: 2px dashed #ccc;
    ">
      <h3>🔒 Premium Content</h3>
      <p>Subscribe in the iOS app to access video guides and detailed instructions</p>
      <a href="https://apps.apple.com/app/healthhub" style="
        display: inline-block;
        background: #2E7D32;
        color: white;
        padding: 12px 24px;
        text-decoration: none;
        border-radius: 8px;
        margin-top: 12px;
      ">
        Download iOS App
      </a>
    </div>
  </div>
</div>
```

### 4. JavaScript Authentication System
Add this complete authentication system to your webapp:

```javascript
class HealthHubAuth {
  constructor() {
    this.baseURL = 'YOUR_AUTH_SERVER_URL/api'; // Replace with your deployed server
    this.token = localStorage.getItem('healthhub_token');
    this.user = this.getStoredUser();
    this.isAuthenticated = !!this.token;
    this.subscriptionStatus = null;
    
    this.init();
  }

  init() {
    // Configure Apple Sign In
    AppleID.auth.init({
      clientId: 'com.yourcompany.healthhub', // Your iOS bundle ID
      scope: 'name email',
      redirectURI: window.location.origin,
      state: 'webapp'
    });

    if (this.isAuthenticated) {
      this.checkSubscriptionStatus();
    }
    this.setupEventListeners();
    this.onAuthStateChange();
  }

  async signInWithApple() {
    try {
      const appleAuth = await AppleID.auth.signIn();
      const { authorization } = appleAuth;
      
      const response = await fetch(`${this.baseURL}/auth/apple`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          appleUserId: authorization.user,
          email: authorization.email || '',
          identityToken: authorization.id_token
        })
      });

      const data = await response.json();
      
      if (data.success) {
        this.setAuthData(data.token, data.user);
        await this.checkSubscriptionStatus();
        this.onAuthStateChange();
      }
    } catch (error) {
      console.error('Apple Sign In error:', error);
      this.showError('Sign in failed. Please try again.');
    }
  }

  async checkSubscriptionStatus() {
    if (!this.token) return;

    try {
      const response = await fetch(`${this.baseURL}/subscription/status`, {
        headers: { 'Authorization': `Bearer ${this.token}` }
      });

      const data = await response.json();
      this.subscriptionStatus = data;
      this.updateUIForSubscription(data.isActive);
    } catch (error) {
      console.error('Subscription check error:', error);
    }
  }

  updateUIForSubscription(isActive) {
    // Show/hide premium content
    document.querySelectorAll('.premium-content').forEach(el => {
      el.style.display = isActive ? 'block' : 'none';
    });
    
    document.querySelectorAll('.content-locked').forEach(el => {
      el.style.display = isActive ? 'none' : 'block';
    });

    // Update status display
    const statusElement = document.querySelector('.subscription-status');
    if (statusElement) {
      statusElement.innerHTML = isActive 
        ? '<span style="color: #4CAF50; font-weight: 600;">✅ Premium Active</span>'
        : '<span style="color: #666;">🔒 Subscribe in iOS app for premium content</span>';
    }
  }

  setAuthData(token, user) {
    this.token = token;
    this.user = user;
    this.isAuthenticated = true;
    localStorage.setItem('healthhub_token', token);
    localStorage.setItem('healthhub_user', JSON.stringify(user));
  }

  getStoredUser() {
    const userData = localStorage.getItem('healthhub_user');
    return userData ? JSON.parse(userData) : null;
  }

  logout() {
    this.token = null;
    this.user = null;
    this.isAuthenticated = false;
    this.subscriptionStatus = null;
    localStorage.removeItem('healthhub_token');
    localStorage.removeItem('healthhub_user');
    this.onAuthStateChange();
  }

  onAuthStateChange() {
    const loginButton = document.querySelector('.login-button');
    const logoutButton = document.querySelector('.logout-button');
    const userProfile = document.querySelector('.user-profile');

    if (this.isAuthenticated) {
      if (loginButton) loginButton.style.display = 'none';
      if (logoutButton) logoutButton.style.display = 'block';
      if (userProfile) {
        userProfile.style.display = 'block';
        userProfile.innerHTML = `Welcome, ${this.user?.email || 'User'}`;
      }
    } else {
      if (loginButton) loginButton.style.display = 'block';
      if (logoutButton) logoutButton.style.display = 'none';
      if (userProfile) userProfile.style.display = 'none';
      this.updateUIForSubscription(false);
    }
  }

  setupEventListeners() {
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('apple-signin-btn')) {
        this.signInWithApple();
      }
      if (e.target.classList.contains('logout-btn')) {
        this.logout();
      }
    });

    // Auto-refresh subscription status every 5 minutes
    setInterval(() => {
      if (this.isAuthenticated) {
        this.checkSubscriptionStatus();
      }
    }, 5 * 60 * 1000);
  }

  showError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.textContent = message;
    errorDiv.style.cssText = `
      position: fixed; top: 20px; right: 20px;
      background: #ff4444; color: white;
      padding: 12px 20px; border-radius: 8px;
      z-index: 10000;
    `;
    document.body.appendChild(errorDiv);
    setTimeout(() => errorDiv.remove(), 5000);
  }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
  window.healthHubAuth = new HealthHubAuth();
});
```

### 5. CSS Styling
Add these styles:
```css
.auth-section { display: flex; align-items: center; gap: 12px; padding: 12px 0; }
.status-active { color: #4CAF50; font-weight: 600; }
.status-inactive { color: #666; font-weight: 500; }
.premium-content { animation: fadeIn 0.3s ease-in-out; }
.content-locked { animation: fadeIn 0.3s ease-in-out; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
.apple-signin-btn:hover { background: #333 !important; transform: translateY(-1px); transition: all 0.2s ease; }
.logout-btn:hover { background: #888 !important; transition: all 0.2s ease; }
```

## Implementation Strategy

### Step 1: Configure Authentication
1. Update `this.baseURL` to your deployed auth server URL
2. Replace `clientId` with your actual iOS bundle ID (e.g., "com.yourcompany.healthhub")
3. Test Apple Sign In button appears and works

### Step 2: Identify Premium Content
1. Wrap video content, detailed instructions, and premium remedies with `premium-content` class
2. Add `content-locked` divs as placeholders
3. Test content shows/hides based on subscription status

### Step 3: Test Flow
1. User without subscription sees locked content with iOS app download link
2. User signs in with Apple → system checks subscription status
3. If subscribed on iOS → premium content unlocks automatically
4. Logout works and re-locks content

### Step 4: Deploy
1. Deploy auth server (Heroku/Railway/Vercel)
2. Update `baseURL` in JavaScript
3. Configure Apple Developer portal with your webapp domain
4. Test end-to-end: iOS purchase → web unlock

## Expected Behavior
- **Unauthenticated users**: See locked content with iOS app download prompt
- **Authenticated free users**: See subscription prompt with iOS app link
- **Authenticated premium users**: See all content unlocked with premium badge
- **Cross-platform sync**: iOS subscription automatically unlocks web content

## Server Configuration Required
Your auth server needs to be deployed with these environment variables:
- `APPLE_SHARED_SECRET`: Your App Store Connect shared secret
- `JWT_SECRET`: Secure random string for token generation
- Database configured for user/subscription storage

The authentication system is designed to be resilient - if auth fails, users can still access basic content and are directed to the iOS app for the full experience.