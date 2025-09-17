# 🍃 Your HealHub Configuration Details

## ✅ Your Specific Settings

### Bundle ID: `com.healhubremedies.app`
### Railway URL: `https://web-production-f34b.up.railway.app`
### API Endpoint: `https://web-production-f34b.up.railway.app/api`

---

## 📱 Next Steps (In Order)

### 1. ✅ Update Railway Configuration (Do Now)
Your server is deployed! Now push the updated code:

```bash
cd /mnt/c/HRapp
git add .
git commit -m "Add environment variable support for JWT and Apple secrets"
git push origin main
```

Railway will auto-deploy the changes.

### 2. 📋 Transfer Files to MacBook
Copy these files to a USB drive or cloud storage:
- `/mnt/c/HRapp/iOS_Transfer_Package/` (entire folder)
- This config file (`YOUR_HEALHUB_CONFIG.md`)

### 3. 🍎 On Your MacBook (When Xcode is Ready)

#### A. App Store Connect Setup:
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Enter:
   - Platform: iOS
   - Name: HealHub
   - Primary Language: English
   - Bundle ID: Select "+" and enter `com.healhubremedies.app`
   - SKU: `HEALHUB001`

#### B. Create In-App Purchase:
1. In your app, go to "Monetization" → "In-App Purchases"
2. Click "+" to create
3. Type: Auto-Renewable Subscription
4. Reference Name: HealHub Premium Monthly
5. Product ID: `com.healhubremedies.app.premium.monthly`
6. Price: $4.99

#### C. Get Shared Secret:
1. Go to "General" → "App Information"
2. Find "App-Specific Shared Secret"
3. Click "Generate"
4. Copy the secret
5. Add it to Railway as `APPLE_SHARED_SECRET`

### 4. 🛠 In Xcode:

#### Create Project:
- Open Xcode
- Create New Project → iOS → App
- Product Name: `HealHub`
- Team: Your Apple Developer account
- Bundle Identifier: `com.healhubremedies.app`
- Interface: SwiftUI
- Language: Swift

#### Add Capabilities:
1. Click project → "Signing & Capabilities"
2. Click "+" → Add:
   - Sign in with Apple
   - In-App Purchase
   - CloudKit (optional for now)

#### Add Code Files:
1. Replace ContentView.swift with ContentView_Enhanced.swift
2. Add ios_auth_integration.swift to project
3. Update this line in ios_auth_integration.swift:
   ```swift
   private let baseURL = "https://web-production-f34b.up.railway.app/api"
   ```

### 5. 🌐 Update Web App (Back on Windows)

Use this updated Orchids prompt:

```
I need to integrate Apple Sign In authentication into my HealHub remedy webapp. Users purchase subscriptions through my iOS app and use the same login on web to access premium content.

Please add:
1. Apple Sign In button to the header
2. Authentication system that connects to my server at https://web-production-f34b.up.railway.app/api
3. Premium content gating for videos and detailed remedies
4. Bundle ID for Apple Sign In: com.healhubremedies.app

Use the complete authentication code from ORCHIDS_WEBAPP_INTEGRATION_PROMPT.md, updating:
- baseURL to 'https://web-production-f34b.up.railway.app/api'
- clientId to 'com.healhubremedies.app'

The flow: iOS purchase → Apple Sign In on web → premium content unlocks.
```

---

## 🧪 Testing Checklist

### Server Testing (Do Now):
Visit: https://web-production-f34b.up.railway.app/health

You should see:
```json
{"status":"healthy","timestamp":"2024-XX-XX..."}
```

### iOS Testing (On MacBook):
1. Run app in simulator
2. Test Sign in with Apple
3. Check server logs in Railway

### Web Testing (After Orchids):
1. Click Apple Sign In
2. Verify authentication works
3. Check premium content visibility

---

## ⚠️ Important URLs to Remember

- **Railway Dashboard**: https://railway.app/project/[your-project-id]
- **Your Auth Server**: https://web-production-f34b.up.railway.app
- **API Endpoint**: https://web-production-f34b.up.railway.app/api
- **Health Check**: https://web-production-f34b.up.railway.app/health

---

## 🆘 Quick Fixes

### If authentication fails:
1. Check Railway logs for errors
2. Verify bundle ID matches everywhere
3. Ensure JWT_SECRET is set in Railway

### If server returns 404:
- Make sure to use `/api` in your endpoints
- Check Railway deployment status

### Next Communication:
When you get the Apple Shared Secret from App Store Connect, add it to Railway variables!