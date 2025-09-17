// HealthHub Web App Authentication System
// Add this to your existing webapp

class HealthHubAuth {
  constructor() {
    this.baseURL = 'http://localhost:3001/api'; // Change to your server URL
    this.token = localStorage.getItem('healthhub_token');
    this.user = this.getStoredUser();
    this.isAuthenticated = !!this.token;
    this.subscriptionStatus = null;
    
    this.init();
  }

  init() {
    if (this.isAuthenticated) {
      this.checkSubscriptionStatus();
    }
    this.setupEventListeners();
  }

  async signInWithApple() {
    try {
      // Apple Sign In Web implementation
      const appleAuth = await AppleID.auth.signIn({
        clientId: 'your.app.bundle.id', // Replace with your bundle ID
        redirectURI: window.location.origin,
        scope: 'name email',
        state: 'webapp-signin'
      });

      const { authorization } = appleAuth;
      
      // Send to your backend
      const response = await fetch(`${this.baseURL}/auth/apple`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
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
      } else {
        throw new Error(data.error || 'Authentication failed');
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
        headers: {
          'Authorization': `Bearer ${this.token}`
        }
      });

      const data = await response.json();
      this.subscriptionStatus = data;
      this.updateUIForSubscription(data.isActive);
    } catch (error) {
      console.error('Subscription check error:', error);
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

  updateUIForSubscription(isActive) {
    // Update premium content visibility
    const premiumElements = document.querySelectorAll('.premium-content');
    const lockedElements = document.querySelectorAll('.content-locked');
    
    premiumElements.forEach(el => {
      el.style.display = isActive ? 'block' : 'none';
    });
    
    lockedElements.forEach(el => {
      el.style.display = isActive ? 'none' : 'block';
    });

    // Update subscription status display
    const statusElement = document.querySelector('.subscription-status');
    if (statusElement) {
      statusElement.innerHTML = isActive 
        ? '<span class="status-active">✅ Premium Active</span>'
        : '<span class="status-inactive">🔒 Subscribe in iOS app</span>';
    }
  }

  onAuthStateChange() {
    // Update login/logout buttons
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
    }

    // Hide all premium content if not authenticated
    if (!this.isAuthenticated) {
      this.updateUIForSubscription(false);
    }
  }

  setupEventListeners() {
    // Login button
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('apple-signin-btn')) {
        this.signInWithApple();
      }
      
      if (e.target.classList.contains('logout-btn')) {
        this.logout();
      }
    });

    // Auto-refresh subscription status periodically
    setInterval(() => {
      if (this.isAuthenticated) {
        this.checkSubscriptionStatus();
      }
    }, 5 * 60 * 1000); // Every 5 minutes
  }

  showError(message) {
    // Simple error display
    const errorDiv = document.createElement('div');
    errorDiv.className = 'auth-error';
    errorDiv.textContent = message;
    errorDiv.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #ff4444;
      color: white;
      padding: 12px 20px;
      border-radius: 8px;
      z-index: 10000;
    `;
    
    document.body.appendChild(errorDiv);
    
    setTimeout(() => {
      errorDiv.remove();
    }, 5000);
  }
}

// Initialize authentication when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.healthHubAuth = new HealthHubAuth();
});

// HTML to add to your webapp
const authHTML = `
<!-- Add this to your webapp header -->
<div class="auth-section">
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

<!-- Subscription status indicator -->
<div class="subscription-status" style="
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 14px;
  margin: 10px 0;
"></div>

<!-- Premium content wrapper example -->
<div class="remedy-video">
  <div class="premium-content" style="display: none;">
    <!-- Your actual video content -->
    <video controls>
      <source src="remedy-video.mp4" type="video/mp4">
    </video>
  </div>
  
  <div class="content-locked">
    <div style="
      background: rgba(0,0,0,0.1);
      padding: 40px;
      text-align: center;
      border-radius: 12px;
      border: 2px dashed #ccc;
    ">
      <h3>🔒 Premium Content</h3>
      <p>Subscribe in the iOS app to access video guides</p>
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
`;

// CSS for authentication UI
const authCSS = `
<style>
.auth-section {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
}

.status-active {
  color: #4CAF50;
  font-weight: 600;
}

.status-inactive {
  color: #666;
  font-weight: 500;
}

.premium-content {
  animation: fadeIn 0.3s ease-in-out;
}

.content-locked {
  animation: fadeIn 0.3s ease-in-out;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.apple-signin-btn:hover {
  background: #333 !important;
  transform: translateY(-1px);
  transition: all 0.2s ease;
}

.logout-btn:hover {
  background: #888 !important;
  transition: all 0.2s ease;
}
</style>
`;

// Apple Sign In Web SDK script (add to your HTML head)
const appleSDKScript = `
<script src="https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"></script>
<script>
  // Configure Apple Sign In
  AppleID.auth.init({
    clientId: 'your.app.bundle.id', // Replace with your bundle ID
    scope: 'name email',
    redirectURI: window.location.origin,
    state: 'webapp'
  });
</script>
`;

console.log('HealthHub Web Authentication System loaded');
console.log('Add the following HTML to your webapp:', authHTML);
console.log('Add the following to your HTML head:', appleSDKScript);