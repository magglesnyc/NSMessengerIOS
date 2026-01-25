//
//  ChatView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var navigateToChat = false
    
    private let tabs = ["Chats", "Contacts"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with current user info
                ChatViewHeader(
                    user: authService.authState.user,
                    onProfileTap: { showingSettings = true }
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
                            .padding(.vertical, Spacing.md)
                            
                            // Chat list
                            if viewModel.filteredChats.isEmpty {
                                ChatEmptyStateView()
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(viewModel.filteredChats) { chat in
                                            ChatListRowView(
                                                chat: chat,
                                                onTap: {
                                                    viewModel.selectChat(chat.conversationId)
                                                    navigateToChat = true
                                                }
                                            )
                                            
                                            if chat.id != viewModel.filteredChats.last?.id {
                                                Divider()
                                                    .padding(.leading, 70)
                                            }
                                        }
                                    }
                                }
                                .background(Color.backgroundWhite)
                            }
                        }
                    } else {
                        // Contacts view
                        ContactsView { conversationId in
                            selectedTab = 0
                            viewModel.selectChat(conversationId)
                            navigateToChat = true
                        }
                    }
                }
                
                // Bottom tab bar
                ChatTabBar(
                    selectedTab: $selectedTab,
                    tabs: tabs
                )
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSettings) {
            SettingsView(authViewModel: AuthViewModel())
        }
        .background(
            NavigationLink(
                destination: ChatDetailView(viewModel: viewModel),
                isActive: $navigateToChat
            ) { EmptyView() }
        )
    }
}

struct ChatEmptyStateView: View {
    var body: some View {
        EmptyStateView(
            icon: "message",
            title: "No Chats Yet",
            subtitle: "Start a conversation by selecting a contact from the Contacts tab",
            actionText: nil,
            action: nil
        )
    }
}

struct ChatViewHeader: View {
    let user: UserInfo?
    let onProfileTap: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // User avatar and info
            Button(action: onProfileTap) {
                HStack(spacing: Spacing.md) {
                    AvatarView(
                        imageURL: user?.firstName?.isEmpty == false ? nil : nil, // UserInfo doesn't have profilePhotoUrl
                        size: 40,
                        showStatus: true,
                        status: .available
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.displayName ?? "John Doe")
                            .font(.lato(16, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Available")
                            .font(.lato(12, weight: .regular))
                            .foregroundColor(.successGreen)
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
                        .font(.system(size: 20))
                        .foregroundColor(.textPrimary)
                }
                
                Button(action: {
                    // Menu action
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.backgroundWhite)
    }
}

struct ChatListRowView: View {
    let chat: ChatItemDto
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
                            .font(.lato(16, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(chat.lastMessageTime)
                            .font(.lato(12, weight: .regular))
                            .foregroundColor(.textSecondary)
                    }
                    
                    HStack {
                        // Show unread message indicator instead of actual content
                        if chat.unreadCount > 0 {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.primaryPurple)
                                
                                Text("New message")
                                    .font(.lato(14, weight: .medium))
                                    .foregroundColor(.primaryPurple)
                            }
                        } else {
                            Text("No new messages")
                                .font(.lato(14, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.lato(12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primaryPurple)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .background(Color.backgroundWhite)
    }
}


struct ChatTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    Text(tabs[index])
                        .font(.lato(16, weight: selectedTab == index ? .bold : .medium))
                        .foregroundColor(selectedTab == index ? .white : .textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            selectedTab == index 
                                ? Color.primaryPurple
                                : Color.clear
                        )
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.backgroundGray)
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
}
