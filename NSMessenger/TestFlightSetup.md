# TestFlight Setup Guide for NSMessenger

## Prerequisites Checklist

- [ ] Apple Developer Account (enrolled and active)
- [ ] Xcode 14+ installed
- [ ] NSMessenger project files ready
- [ ] Bundle identifier chosen (e.g., `com.yourcompany.nsmessenger`)
- [ ] App icons prepared (required sizes below)

## Step 1: Xcode Project Configuration

### A. Create New Xcode Project
1. Open Xcode
2. Create new project → iOS → App
3. Use these settings:
   - **Product Name**: NSMessenger
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Bundle Identifier**: `com.maggles.nsmessenger` (or your preferred ID)
   - **Team**: Select your Apple Developer Team

### B. Import Your Files
1. Drag all your Swift files from the repository into the Xcode project
2. Make sure to add them to the target
3. Organize into groups:
   ```
   NSMessenger/
   ├── App/
   │   ├── NSMessengerApp.swift
   │   └── ContentView.swift
   ├── Models/
   │   ├── AuthModels.swift
   │   └── ChatModels.swift
   ├── Services/
   │   ├── AuthService.swift
   │   ├── MessagingService.swift
   │   └── SignalRService.swift
   ├── Views/
   ├── ViewModels/
   ├── Components/
   ├── DesignSystem/
   └── Utilities/
   ```

### C. Configure Package Dependencies
1. In Xcode: **File** → **Add Package Dependencies**
2. Add SignalR: `https://github.com/moozzyk/SignalR-Client-Swift`
3. Select your target and add the dependency

## Step 2: App Icons & Assets

You'll need app icons in these sizes. Create them and add to Assets.xcassets:

### Required App Icon Sizes:
- **iPhone**: 60x60@2x (120x120), 60x60@3x (180x180)
- **iPad**: 76x76@1x (76x76), 76x76@2x (152x152), 83.5x83.5@2x (167x167)
- **App Store**: 1024x1024@1x

### Quick Icon Creation:
I recommend using SF Symbols or creating a simple purple icon with "NS" initials to start.

## Step 3: App Store Connect Setup

### A. Create App Record
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **Apps** → **+** → **New App**
3. Fill out:
   - **Platform**: iOS
   - **Name**: NSMessenger
   - **Primary Language**: English
   - **Bundle ID**: (select the one you configured in Xcode)
   - **SKU**: `NSMessenger-iOS-2025` (or similar unique identifier)

### B. App Information
Fill out the basic app information:
- **Subtitle**: Real-time Team Messaging
- **Privacy Policy URL**: (create a simple one if needed)
- **Category**: Business or Social Networking
- **Content Rights**: (indicate if you have rights to use all content)

## Step 4: Build & Archive

### A. Configure Build Settings
1. In Xcode, select your project
2. Go to **Build Settings**
3. Set **Code Signing Identity** to your developer certificate
4. Set **Provisioning Profile** to automatic
5. Make sure **Deployment Target** is iOS 15.0

### B. Create Archive
1. Select **Generic iOS Device** as target (not simulator)
2. **Product** → **Archive**
3. Wait for build to complete
4. In Organizer, click **Distribute App**
5. Choose **App Store Connect**
6. Upload for TestFlight

## Step 5: TestFlight Configuration

### A. After Upload
1. Go back to App Store Connect
2. Go to your app → **TestFlight** tab
3. Wait for processing (usually 10-30 minutes)
4. Once processed, you'll see your build

### B. Add Beta Testers
1. **TestFlight** → **Internal Testing**
2. Create a group: "NSMessenger Beta Team"
3. Add testers by email address
4. Enable testing for your build

### C. External Testing (Optional)
For wider beta testing:
1. **TestFlight** → **External Testing**
2. Submit for Beta App Review (required for external testers)
3. Add up to 10,000 external testers

## Step 6: Testing & Iteration

### Testing Checklist:
- [ ] App launches successfully
- [ ] Authentication flow works
- [ ] Real-time messaging functions
- [ ] Contact management works
- [ ] Environment switching works
- [ ] No crashes on basic usage

### Common Issues & Fixes:
1. **Build Errors**: Check package dependencies and Swift version
2. **Code Signing Issues**: Verify Apple Developer membership and certificates
3. **Missing Icons**: App won't upload without proper icon sizes
4. **Network Issues**: Ensure Info.plist has proper network security settings

## Step 7: Prepare for App Store Review

When ready for full release:
1. Add **App Store** screenshots (required sizes)
2. Write **App Store Description** (use the one I created)
3. Set **Pricing & Availability**
4. Submit for **App Store Review**

## Quick Start Script

Here's what you need to do right now:

1. **Create Xcode project** with the settings above
2. **Add your Swift files** from the repository
3. **Add SignalR package dependency**
4. **Create basic app icons** (even temporary ones)
5. **Archive and upload** to TestFlight

## Need Help?

Common next steps I can help with:
- Creating App Store screenshots
- Writing privacy policy
- Configuring push notifications
- Adding more app icons
- Debugging build issues

Would you like me to help you with any specific step, or do you have questions about the Apple Developer setup process?