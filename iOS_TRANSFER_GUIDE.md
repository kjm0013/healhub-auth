# 📱 HealHub iOS Transfer & Setup Guide

## Files to Transfer to MacBook

All iOS files are in the `iOS_Transfer_Package` folder:
- **ContentView_Enhanced.swift** - Complete iOS app UI
- **ios_auth_integration.swift** - Authentication system
- **webapp_remedies_data.json** - Initial remedy data

## 🎯 Quick Overview - What We're Doing

1. **Now (Windows)**: Deploy server → Get server URL
2. **MacBook**: Create iOS app in Xcode → Add our code
3. **App Store Connect**: Create app → Set up subscriptions
4. **Webapp**: Update with Orchids using server URL
5. **Test**: Buy subscription on iOS → Access on web

---

## 📋 Order of Operations

### Phase 1: Server Deployment (Do Now on Windows)
1. Deploy to Railway
2. Get your server URL
3. Configure environment variables

### Phase 2: Apple Setup (On MacBook)
1. Create App Store Connect app
2. Configure In-App Purchase
3. Get shared secret

### Phase 3: iOS App (On MacBook)
1. Create Xcode project
2. Add our Swift code
3. Configure capabilities
4. Update server URLs

### Phase 4: Web Integration (Back on Windows)
1. Use Orchids with server URL
2. Test authentication flow

---

## 🚀 What You Need Ready

### For Railway Deployment:
- GitHub account ✅ (you have this)
- Railway account (free)

### For Apple:
- Apple Developer account ✅ (you have this)
- Bundle ID decision (e.g., `com.yourname.healhub`)

### For Transfer:
- USB drive or cloud storage
- Copy the `iOS_Transfer_Package` folder

---

## 💡 Bundle ID Naming

Choose your bundle ID now (you'll need it everywhere):
- Format: `com.yourcompany.healhub`
- Examples:
  - `com.kjm.healhub`
  - `com.mortimer.healhub`
  - `com.risenorth.healhub`

This MUST match exactly in:
- Xcode project
- App Store Connect
- Authentication server
- Web app JavaScript

---

## 📱 What Happens on MacBook

### 1. Create Xcode Project:
- Product Name: HealHub
- Bundle ID: [your chosen ID]
- Language: Swift
- Interface: SwiftUI

### 2. Add Capabilities:
- Sign in with Apple
- In-App Purchase
- CloudKit

### 3. Copy Our Code:
- Replace ContentView.swift with ContentView_Enhanced.swift
- Add ios_auth_integration.swift to project
- Update server URL in auth code

### 4. Test on Simulator:
- Run app
- Test subscription flow
- Verify authentication

---

## 🌐 Server URL Updates

Once Railway gives you a URL like:
`https://healhub-auth-production.up.railway.app`

Update these locations:

### In iOS App (ios_auth_integration.swift):
```swift
private let baseURL = "https://healhub-auth-production.up.railway.app/api"
```

### In Webapp (via Orchids):
```javascript
this.baseURL = 'https://healhub-auth-production.up.railway.app/api';
```

### In App Store Connect:
- Server URL for receipt validation

---

## ✅ Tonight's Checklist

**Windows (Now):**
- [ ] Deploy server to Railway
- [ ] Get production server URL
- [ ] Set JWT_SECRET in Railway

**MacBook (After Xcode downloads):**
- [ ] Create App Store Connect app
- [ ] Set up subscription product
- [ ] Create Xcode project
- [ ] Add authentication code
- [ ] Update server URLs
- [ ] Test in simulator

**Windows (After MacBook):**
- [ ] Update webapp with Orchids
- [ ] Test complete flow

---

## 🔧 Common Issues & Solutions

### "Bundle ID doesn't match"
- Ensure same ID in Xcode, App Store Connect, and auth code

### "Authentication failed"
- Check server URL has `/api` at the end
- Verify JWT_SECRET matches in Railway

### "Subscription not showing"
- Add StoreKit configuration in Xcode
- Test with sandbox account

---

## 📞 Next Steps Communication

After Railway deployment, you'll need:
1. **Railway URL**: Share this between computers
2. **Bundle ID**: Decide and use consistently
3. **Apple Shared Secret**: From App Store Connect

Keep this guide open on both computers!