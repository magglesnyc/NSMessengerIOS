//
//  MobileChatListView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct MobileChatListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var authService = AuthService.shared
    @StateObject private var messagingService = MessagingService.shared
    @State private var selectedTab = 0
    @State private var showingProfileSettings = false
    @State private var showingMenuSettings = false
    @State private var navigateToChat = false
    
    private let tabs = ["Chats", "Contacts"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with current user info
                MobileChatHeader(
                    user: authService.authState.user,
                    onProfileTap: { showingProfileSettings = true },
                    onMenuTap: { showingMenuSettings = true }
                )
                
                // Content based on selected tab
                Group {
                    if selectedTab == 0 {
                        // Chats view
                        VStack(spacing: 0) {
                            // Search bar
                            SearchBar(
                                text: $viewModel.searchText,
                                placeholder: "Search Chats",
                                onTextChanged: { _ in }
                            )
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.md)
                            
                            // Chat list or empty state
                            if viewModel.filteredChats.isEmpty {
                                EmptyChatsView(onAddContactsTap: {
                                    selectedTab = 1 // Switch to Contacts tab
                                })
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(viewModel.filteredChats) { chat in
                                            MobileChatItem(
                                                chat: chat,
                                                onTap: {
                                                    // Navigate to chat detail view
                                                    viewModel.selectChat(chat.conversationId)
                                                    navigateToChat = true
                                                }
                                            )
                                            .background(Color.backgroundWhite)
                                        }
                                    }
                                }
                                .background(Color.backgroundWhite)
                            }
                        }
                        .background(Color.backgroundWhite)
                    } else {
                        // Contacts view
                        ContactsView { conversationId in
                            // Switch to chats and select conversation
                            selectedTab = 0
                            viewModel.selectChat(conversationId)
                            navigateToChat = true
                        }
                    }
                }
                
                // Bottom tab bar
                MobileTabBar(
                    selectedTab: $selectedTab,
                    tabs: tabs
                )
            }
            .background(Color.backgroundWhite)
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: ChatDetailView(viewModel: viewModel),
                    isActive: $navigateToChat
                ) { EmptyView() }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingProfileSettings) {
            SettingsView(authViewModel: AuthViewModel())
        }
        .sheet(isPresented: $showingMenuSettings) {
            SettingsView(authViewModel: AuthViewModel())
        }
        .onAppear {
            print("📱 MobileChatListView appeared")
            print("🔍 Current auth state - isAuthenticated: \(authService.authState.isAuthenticated)")
            print("👤 Current user: \(authService.authState.user?.email ?? "none")")
            print("💬 Current chats count: \(viewModel.chats.count)")
            print("👥 Current contacts count: \(messagingService.contacts.count)")
            
            // Ensure data is loaded when view appears
            viewModel.refreshChats()
            
            // Also trigger comprehensive data refresh
            Task {
                print("🔄 Manually triggering comprehensive data refresh...")
                await messagingService.refreshAllData()
            }
        }
        .refreshable {
            print("🔄 Pull-to-refresh triggered")
            viewModel.refreshChats()
            await messagingService.refreshAllData()
        }
    }
}

struct MobileChatHeader: View {
    let user: UserInfo?
    let onProfileTap: () -> Void
    let onMenuTap: () -> Void
    @State private var currentStatus: UserStatusType = .available
    @State private var showingStatusPicker = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // User avatar and info
            Button(action: onProfileTap) {
                HStack(spacing: Spacing.md) {
                    AvatarView(
                        imageURL: nil, // UserInfo doesn't have profilePhotoUrl
                        size: 40,
                        showStatus: true,
                        status: currentStatus
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.displayName ?? "User")
                            .font(.lato(16, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Button(action: {
                            showingStatusPicker = true
                        }) {
                            Text(currentStatus.displayName)
                                .font(.lato(12, weight: .regular))
                                .foregroundColor(currentStatus.displayColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Action buttons
            HStack(spacing: Spacing.lg) {
                Button(action: {
                    // Notifications action
                }) {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(Color.backgroundWhite)
        .overlay(
            Rectangle()
                .fill(Color.borderColor.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .actionSheet(isPresented: $showingStatusPicker) {
            ActionSheet(
                title: Text("Set Your Status"),
                message: Text("Choose your availability status"),
                buttons: [
                    .default(Text("🟢 Available")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStatus = .available
                        }
                    },
                    .default(Text("🟡 Away")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStatus = .away
                        }
                    },
                    .default(Text("🔴 Busy")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStatus = .busy
                        }
                    },
                    .default(Text("⚫ Offline")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStatus = .offline
                        }
                    },
                    .cancel()
                ]
            )
        }
    }
}

struct MobileChatItem: View {
    let chat: ChatItemDto
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.md) {
                    // Avatar
                    AvatarView(
                        imageURL: chat.photoUrl.isEmpty ? nil : chat.photoUrl,
                        size: 50,
                        showStatus: !chat.isGroup,
                        status: UserStatusType(rawValue: chat.status) ?? .offline
                    )
                    
                    // Chat info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chat.name)
                                .font(.lato(16, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: Spacing.xs) {
                                Text(chat.lastMessageTime)
                                    .font(.lato(12, weight: .regular))
                                    .foregroundColor(.textTertiary)
                                
                                if chat.unreadCount > 0 {
                                    Text("\(chat.unreadCount)")
                                        .font(.lato(11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.primaryPurple)
                                        .clipShape(Circle())
                                        .frame(minWidth: 20)
                                }
                            }
                        }
                        
                        Text(chat.lastMessage.isEmpty ? "No messages yet" : "Tap to view messages")
                            .font(.lato(14, weight: .regular))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                
                // Divider
                Divider()
                    .background(Color.borderColor.opacity(0.3))
                    .padding(.leading, Spacing.lg + 50 + Spacing.md) // Align with text content
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

struct MobileTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    Text(tabs[index])
                        .font(.lato(15, weight: .semibold))
                        .foregroundColor(selectedTab == index ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            selectedTab == index 
                                ? Color.primaryPurple
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.backgroundSecondary.opacity(0.9))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

#Preview {
    MobileChatListView(viewModel: ChatViewModel())
}

// MARK: - UserStatusType Extensions
extension UserStatusType {
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .away:
            return "Away"
        case .busy:
            return "Busy"
        case .offline:
            return "Offline"
        }
    }
    
    var displayColor: Color {
        switch self {
        case .available:
            return Color.successGreen
        case .away:
            return Color.warningOrange
        case .busy:
            return Color.errorRed
        case .offline:
            return Color.disabledGray
        }
    }
}

struct EmptyChatsView: View {
    let onAddContactsTap: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.textTertiary)
            
            VStack(spacing: Spacing.md) {
                Text("No Conversations Yet")
                    .font(.lato(18, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text("Start by adding contacts, then create conversations with them.")
                    .font(.lato(14, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
                
                VStack(spacing: Spacing.md) {
                    Text("Steps to get started:")
                        .font(.lato(14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("1.")
                                .font(.lato(14, weight: .bold))
                                .foregroundColor(.primaryPurple)
                            Text("Tap the 'Contacts' tab below")
                                .font(.lato(14, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack {
                            Text("2.")
                                .font(.lato(14, weight: .bold))
                                .foregroundColor(.primaryPurple)
                            Text("Search for users to add as contacts")
                                .font(.lato(14, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack {
                            Text("3.")
                                .font(.lato(14, weight: .bold))
                                .foregroundColor(.primaryPurple)
                            Text("Start conversations with your contacts")
                                .font(.lato(14, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(Spacing.lg)
                .background(Color.backgroundPrimary)
                .cornerRadius(CornerRadius.medium)
                .padding(.horizontal, Spacing.lg)
                
                // Add Contacts button
                Button(action: onAddContactsTap) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                        Text("Go to Contacts")
                            .font(.lato(16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.primaryPurple)
                    .cornerRadius(CornerRadius.standard)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, Spacing.md)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundWhite)
    }
}
