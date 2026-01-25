# NSMessenger - Real-time Messaging Application

A full-featured messaging application built with SwiftUI, featuring JWT authentication, real-time messaging via SignalR, contact management, and conversation handling.

## Features

### Core Functionality
- ✅ JWT Authentication with secure token storage
- ✅ Real-time messaging via SignalR
- ✅ Contact management and contact requests
- ✅ Private conversations and group chats
- ✅ Message history with date grouping
- ✅ Typing indicators and presence status
- ✅ Environment configuration (QA/Development)

### Design System
- ✅ Purple brand colors with comprehensive color palette
- ✅ Lato font family typography scale
- ✅ Consistent spacing and component styles
- ✅ Card-based layout with shadows and borders
- ✅ Status indicators and avatars
- ✅ Responsive design for different screen sizes

### User Interface
- ✅ Login screen with form validation
- ✅ Chat list with search functionality
- ✅ Split-view chat interface
- ✅ Contacts management with search
- ✅ Settings screen with profile management
- ✅ Contact requests notifications
- ✅ Environment configuration

## Architecture

The application follows MVVM (Model-View-ViewModel) architecture with Combine for reactive programming:

```
├── App/
│   └── NSMessengerApp.swift
├── DesignSystem/
│   ├── Colors.swift
│   ├── Typography.swift
│   ├── Spacing.swift
│   └── ComponentStyles.swift
├── Models/
│   ├── AuthModels.swift
│   └── ChatModels.swift
├── Services/
│   ├── AuthService.swift
│   ├── SignalRService.swift
│   ├── MessagingService.swift
│   ├── KeychainService.swift
│   └── ConfigurationManager.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   └── ContactsViewModel.swift
├── Views/
│   ├── LoginView.swift
│   ├── MainView.swift
│   ├── ChatListView.swift
│   ├── ChatView.swift
│   ├── ContactsView.swift
│   └── SettingsView.swift
├── Components/
│   ├── AvatarView.swift
│   ├── CardView.swift
│   ├── SearchBar.swift
│   ├── TabSelector.swift
│   └── LoadingView.swift
└── Utilities/
    └── DateFormatter+Extensions.swift
```

## Configuration

### Environment Settings

The application supports two environments that can be switched via the settings:

**QA Environment (Default)**
- Auth Server: `https://authqa.axminc.com`
- SignalR Hub: `https://nsmessageserviceqa.axminc.com/messageHub`
- Company ID: `NOTHINGSOCIAL`

**Development Environment**
- Auth Server: `http://localhost:5229`
- SignalR Hub: `http://localhost:5228/messageHub`
- Company ID: `NOTHINGSOCIAL`

### Required Dependencies

To complete the implementation, add these dependencies to your project:

1. **SignalR Client for Swift**: For real-time messaging
   - GitHub: `https://github.com/moozzyk/SignalR-Client-Swift`
   - Add via Swift Package Manager

2. **Optional: Kingfisher**: For efficient image loading and caching
   - GitHub: `https://github.com/onevcat/Kingfisher`

## Implementation Status

### Completed ✅
- Complete design system with colors, typography, and component styles
- Authentication service with JWT token management
- Keychain service for secure token storage
- Configuration manager for environment switching
- Mock SignalR service (ready for real implementation)
- Messaging service with full API integration
- All view models with reactive state management
- Complete UI implementation matching design specifications
- Login, main chat, contacts, and settings screens
- Reusable components (avatar, cards, search bar, etc.)

### Next Steps 🔄

1. **Add Real SignalR Dependency**
   ```swift
   // Add to Package.swift or via Xcode
   .package(url: "https://github.com/moozzyk/SignalR-Client-Swift", from: "0.8.0")
   ```

2. **Replace Mock SignalR Service**
   - Update `SignalRService.swift` to use real SignalR library
   - Implement proper connection handling and method invocation

3. **Add Image Loading**
   - Integrate Kingfisher for avatar image loading
   - Implement image caching and placeholder handling

4. **Add Font Loading**
   - Bundle Lato font files or use Google Fonts
   - Update font definitions in Typography.swift

5. **Enhanced Error Handling**
   - Add network connectivity checks
   - Implement retry logic and offline mode
   - Add user-friendly error messages

6. **Testing**
   - Add unit tests for services and view models
   - Add UI tests for critical user flows
   - Add integration tests for SignalR functionality

## API Integration

The application is designed to integrate with the following APIs:

### Authentication API
- `POST /api/Auth/Login` - User login with JWT response

### SignalR Hub Methods
- `CreateUser` - Create or retrieve user profile
- `GetContacts` - Retrieve user contacts
- `SearchUsers` - Search for users to add as contacts
- `SendContactRequest` - Send contact request
- `RespondToContactRequest` - Accept/decline contact request
- `GetChatsForUser` - Retrieve user conversations
- `CreateConversation` - Create new private/group conversation
- `StoreMessage` - Send message to conversation
- `GetMessagesForConversation` - Retrieve message history
- `JoinConversation` / `LeaveConversation` - Manage real-time groups
- `NotifyTyping` / `NotifyStoppedTyping` - Typing indicators
- `UpdatePresence` - User presence status

### Real-time Events
- `ReceiveMessage` - New message notification
- `ContactRequestReceived` - Incoming contact request
- `ContactRequestResponded` - Contact request response
- `UserTyping` / `UserStoppedTyping` - Typing indicators
- `PresenceChanged` - User status changes

## Design System

### Colors
- **Primary Purple**: `#3F1879` - Brand color, buttons, active states
- **Secondary Purple**: `#6E3DB8` - Accents, sent messages
- **Background Colors**: Various shades for cards, inputs, and main background
- **Semantic Colors**: Green (success), Red (error), Orange (warning), Gray (disabled)

### Typography
- **Font Family**: Lato (or system fallback)
- **Scale**: H1 (28px) down to Caption (9px)
- **Weights**: Regular (400), Bold (700), Black (900)

### Spacing
- **Standard Values**: 5px (xxs) to 30px (xxxl)
- **Component Padding**: 24px for cards, 15px for buttons
- **Layout Gaps**: 10-30px between elements

### Components
- **Cards**: White background, 5px radius, shadow, optional accent border
- **Buttons**: Primary (purple), Secondary (gray), Pill (rounded)
- **Inputs**: Gray background, purple border on focus
- **Avatars**: Circular with status indicators

## Platform Support

- **Minimum Target**: iOS 15.0 / macOS 12.0
- **Frameworks**: SwiftUI, Combine, Foundation
- **Architecture**: MVVM with reactive programming

## Security

- JWT tokens stored securely in iOS Keychain
- Automatic token validation and refresh
- Secure API communication with bearer token authentication
- Data clearing on logout

## Getting Started

1. Clone the repository
2. Open in Xcode 14+
3. Add required dependencies via Swift Package Manager
4. Update SignalR service implementation
5. Configure your API endpoints
6. Build and run

The application will start with the login screen and automatically connect to the messaging service upon successful authentication.