# Xcode Project Organization Guide

## Current Problem
Your Xcode project doesn't have the proper folder structure, which is why you're getting prompts about copying files and the compiler can't find types.

## Recommended Xcode Project Structure

```
NSMessenger/
├── App/
│   ├── NSMessengerApp.swift
│   ├── ContentView.swift
│   └── Info.plist
│
├── Models/
│   ├── ModelsMediaModels.swift      ← (SelectedMedia, MediaType, MediaAttachmentDto)
│   ├── ModelsChatModels.swift       ← (ChatMessage, MessageGroup, UserDto, etc.)
│   └── ModelsAuthModels.swift       ← (Auth related models)
│
├── Views/
│   ├── ViewsChatDetailView.swift    ← (Your main chat view)
│   ├── ViewsMediaPickerView.swift   ← (MediaSelectionSheet)
│   ├── ViewsMobileChatListView.swift
│   ├── ViewsLoginView.swift
│   └── ViewsContactsView.swift
│
├── ViewModels/
│   ├── ViewModelsChatViewModel.swift ← (ChatViewModel)
│   └── ViewModelsContactsViewModel.swift
│
├── Services/
│   ├── ServicesMediaService.swift   ← (MediaService)
│   ├── ServicesAuthService.swift
│   ├── ServicesSignalRService.swift
│   ├── ServicesMessagingService.swift
│   └── ServicesSSLCertificateHelper.swift
│
├── Utilities/
│   └── UtilitiesKeyboardManager.swift ← (KeyboardManager)
│
└── DesignSystem/
    └── DesignSystemSpacing.swift    ← (Spacing constants)
```

## Step-by-Step Setup Instructions

### 1. Create Groups in Xcode
Right-click your project name → "New Group" for each:
- Models
- Views  
- ViewModels
- Services
- Utilities
- DesignSystem

### 2. Add Files to Groups

**For ServicesMediaService.swift (and other missing files):**

1. Right-click the "Services" group
2. Choose "Add Files to 'NSMessenger'"
3. Navigate to your project folder
4. Select `ServicesMediaService.swift`
5. **Important choices in the dialog:**
   - ✅ "Copy items if needed" (if files are outside project)
   - ✅ "Create groups" (NOT folders)
   - ✅ "Add to target: NSMessenger" (your app target)
6. Click "Add"

### 3. Repeat for All Missing Files

Add each file to its appropriate group:

**Models group:** Add all `Models*.swift` files
**Services group:** Add all `Services*.swift` files  
**Views group:** Add all `Views*.swift` files
**ViewModels group:** Add all `ViewModels*.swift` files
**Utilities group:** Add `UtilitiesKeyboardManager.swift`
**DesignSystem group:** Add `DesignSystemSpacing.swift`

### 4. Verify Setup
After adding all files:
- Go to Project → Target → Build Phases → Compile Sources
- Verify ALL .swift files are listed there
- Clean Build Folder (Product → Clean Build Folder)
- Build project

## Expected Result
- ✅ No more "Cannot find type" errors
- ✅ Organized, maintainable project structure
- ✅ All files properly included in target
- ✅ ViewsChatDetailView.swift compiles successfully

## Alternative: Quick Fix (If Organization Can Wait)

If you just want to get it working quickly:
1. Select ALL the `.swift` files from your file system
2. Drag them into your Xcode project (root level)
3. Choose "Create groups" and "Add to target"
4. Organize into groups later

But the proper structure above is recommended for maintainability.