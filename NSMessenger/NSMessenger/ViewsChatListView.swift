//
//  ChatListView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct ChatListView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(
                text: $viewModel.searchText,
                placeholder: "Search chats...",
                onTextChanged: { _ in }
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            
            // Chat list
            if viewModel.filteredChats.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    
                    Image(systemName: "message")
                        .font(.system(size: 50))
                        .foregroundColor(.textTertiary)
                    
                    Text("No chats yet")
                        .font(.h6)
                        .foregroundColor(.textSecondary)
                    
                    Text("Start a conversation by adding a contact")
                        .font(.bodyText)
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .padding(.horizontal, Spacing.xxl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredChats) { chat in
                            ChatListItem(
                                chat: chat,
                                isSelected: viewModel.selectedChatId == chat.conversationId,
                                onTap: {
                                    viewModel.selectChat(chat.conversationId)
                                }
                            )
                            .background(
                                viewModel.selectedChatId == chat.conversationId
                                    ? Color.backgroundPrimary
                                    : Color.backgroundWhite
                            )
                            
                            if chat.id != viewModel.filteredChats.last?.id {
                                Divider()
                                    .padding(.leading, 68) // Offset for avatar
                            }
                        }
                    }
                }
                .background(Color.backgroundWhite)
            }
        }
        .refreshable {
            viewModel.refreshChats()
        }
    }
}

struct ChatListItem: View {
    let chat: ChatItemDto
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                AvatarView(
                    imageURL: chat.photoUrl.isEmpty ? nil : chat.photoUrl,
                    size: 48,
                    showStatus: !chat.isGroup,
                    status: UserStatusType(rawValue: chat.status) ?? .offline
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chat.name)
                            .font(.lato(14, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(chat.lastMessageTime)
                            .font(.lato(10, weight: .regular))
                            .foregroundColor(.textTertiary)
                    }
                    
                    HStack {
                        Text(chat.lastMessage.isEmpty ? "No messages yet" : "Tap to view messages")
                            .font(.lato(12, weight: .regular))
                            .foregroundColor(chat.lastMessage.isEmpty ? .textTertiary : .textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.lato(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primaryPurple)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        ChatListView(viewModel: ChatViewModel())
    }
}
