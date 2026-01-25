//
//  ChatViewModel.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var chats: [ChatItemDto] = []
    @Published var selectedChatId: UUID?
    @Published var currentMessages: [MessageDto] = []
    @Published var messageText = ""
    @Published var isTyping = false
    @Published var typingUsers: Set<UUID> = []
    @Published var messageGroups: [MessageGroup] = []
    /// Published property to trigger scroll to bottom from outside
    @Published var shouldScrollToBottom = false
    
    /// Method to trigger scroll to bottom with better reliability
    func scrollToBottom() {
        print("📜 ChatViewModel: Triggering scroll to bottom")
        shouldScrollToBottom = true
        // Reset after a longer delay to ensure scroll completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldScrollToBottom = false
        }
    }
    
    private let messagingService = MessagingService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    
    var filteredChats: [ChatItemDto] {
        if searchText.isEmpty {
            return chats
        } else {
            return chats.filter { chat in
                chat.name.localizedCaseInsensitiveContains(searchText) ||
                chat.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var currentUser: UserInfo? {
        authService.authState.user
    }
    
    init() {
        observeMessagingService()
    }
    
    private func observeMessagingService() {
        // Observe chats
        messagingService.$chats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chats in
                print("🔄 ChatViewModel received \(chats.count) chats")
                self?.chats = chats.sorted { chat1, chat2 in
                    // Sort by pinned first, then by last message time
                    if chat1.isPinned != chat2.isPinned {
                        return chat1.isPinned
                    }
                    return chat1.lastMessageTime > chat2.lastMessageTime
                }
            }
            .store(in: &cancellables)
        
        // Observe current messages
        messagingService.$currentMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                print("🔄 ChatViewModel received \(messages.count) messages")
                for (index, message) in messages.enumerated() {
                    print("   📝 Message \(index): '\(message.content)' from \(message.senderDisplayName) at \(message.sentDate)")
                }
                self?.currentMessages = messages
                self?.updateMessageGroups()
            }
            .store(in: &cancellables)
        
        // Observe typing users
        messagingService.$typingUsers
            .receive(on: DispatchQueue.main)
            .assign(to: &$typingUsers)
    }
    
    private func updateMessageGroups() {
        print("🔄 Updating message groups with \(currentMessages.count) messages")
        
        // Debug current user info
        if let currentUser = currentUser {
            print("👤 Current user ID: \(currentUser.userId)")
        } else {
            print("❌ No current user available")
        }
        
        // Log all incoming messages for debugging
        for (index, message) in currentMessages.enumerated() {
            print("📝 Processing message \(index): '\(message.content)' from \(message.senderDisplayName)")
        }
        
        let groupedMessages = Dictionary(grouping: currentMessages) { message in
            Calendar.current.startOfDay(for: message.sentDate)
        }
        
        print("📊 Created \(groupedMessages.keys.count) date groups")
        
        messageGroups = groupedMessages.sorted { $0.key < $1.key }.map { date, messages in
            let chatMessages = messages.map { message in
                let isFromCurrent = UUID(uuidString: message.senderId) == currentUser?.userId
                
                // Debug message info with detailed timestamp information
                print("📝 Converting message: '\(message.content)'")
                print("   ID: \(message.id)")
                print("   Sender ID: \(message.senderId)")
                print("   Sender Name: \(message.senderDisplayName)")
                print("   Is from current user: \(isFromCurrent)")
                print("   Raw sentDate: \(message.sentDate)")
                print("   Formatted timestamp: \(DateFormatter.messageTime.string(from: message.sentDate))")
                
                return ChatMessage(
                    id: message.id,
                    senderId: message.senderId,
                    senderName: message.senderDisplayName,
                    content: message.content,
                    timestamp: message.sentDate, // This should be the actual server timestamp
                    isFromCurrentUser: isFromCurrent,
                    isRead: true
                )
            }.sorted { $0.timestamp < $1.timestamp }
            
            return MessageGroup(
                dateLabel: formatDateLabel(date),
                messages: chatMessages
            )
        }
        
        print("✅ Created \(messageGroups.count) message groups")
        
        // Log final message groups for debugging
        for (groupIndex, group) in messageGroups.enumerated() {
            print("📚 Group \(groupIndex): \(group.dateLabel) with \(group.messages.count) messages")
            if group.messages.count > 0 {
                print("   First: '\(group.messages.first?.content ?? "")'")
                print("   Last: '\(group.messages.last?.content ?? "")'")
            }
        }
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            // Trigger scroll to bottom for new messages
            self.scrollToBottom()
        }
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    func selectChat(_ chatId: UUID) {
        print("📱 ChatViewModel: Selecting chat: \(chatId)")
        selectedChatId = chatId
        
        // Clear current messages first to ensure clean state
        currentMessages = []
        messageGroups = []
        
        Task {
            await messagingService.debugConversationSelection(chatId)
            
            // Wait longer for messages to load properly on device
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            // Trigger UI update and scroll to bottom
            await MainActor.run {
                objectWillChange.send()
                // Trigger scroll to bottom when switching chats with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.scrollToBottom()
                }
            }
        }
    }
    
    func sendMessage() {
        guard let conversationId = selectedChatId,
              !messageText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespaces)
        messageText = ""
        
        Task {
            let success = await messagingService.sendMessage(content, to: conversationId)
            if success {
                // Scroll to bottom after sending message
                await MainActor.run {
                    scrollToBottom()
                }
            } else {
                // Handle error - maybe show a retry option
                print("Failed to send message")
            }
        }
        
        // Stop typing notification
        stopTyping()
    }
    
    func startTyping() {
        guard let conversationId = selectedChatId, !isTyping else { return }
        
        isTyping = true
        Task {
            await messagingService.notifyTyping(in: conversationId)
        }
        
        // Reset typing timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.stopTyping()
        }
    }
    
    func stopTyping() {
        guard let conversationId = selectedChatId, isTyping else { return }
        
        isTyping = false
        typingTimer?.invalidate()
        typingTimer = nil
        
        Task {
            await messagingService.notifyStoppedTyping(in: conversationId)
        }
    }
    
    func onMessageTextChanged(_ newValue: String) {
        if !newValue.isEmpty && !isTyping {
            startTyping()
        } else if newValue.isEmpty {
            stopTyping()
        } else {
            // Reset typing timer if user is still typing
            typingTimer?.invalidate()
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.stopTyping()
            }
        }
    }
    
    func refreshChats() {
        Task {
            await messagingService.loadChats()
        }
    }
    
    func refreshMessages() async {
        guard let conversationId = selectedChatId else { 
            print("❌ Cannot refresh messages - no conversation selected")
            return 
        }
        
        print("🔄 ChatViewModel: Refreshing messages for conversation: \(conversationId)")
        await messagingService.forceRefreshCurrentConversation()
    }
    
    // MARK: - Debug Methods
    
    func debugConnection() {
        print("\n🔍 ===== CHATVIEWMODEL DEBUG =====")
        print("   Selected chat: \(String(describing: selectedChatId))")
        print("   Current messages: \(currentMessages.count)")
        print("   Message groups: \(messageGroups.count)")
        print("   Auth state: \(authService.authState.isAuthenticated)")
        print("   Message text: '\(messageText)'")
        print("   Is typing: \(isTyping)")
        print("   Typing users: \(typingUsers)")
        
        // Debug each message
        if !currentMessages.isEmpty {
            print("\n📝 VIEWMODEL MESSAGES:")
            for (index, message) in currentMessages.enumerated() {
                print("   [\(index)] ID=\(message.id), content='\(message.content)', date=\(message.sentDate)")
            }
        }
        
        // Debug each message group
        if !messageGroups.isEmpty {
            print("\n📚 MESSAGE GROUPS:")
            for (groupIndex, group) in messageGroups.enumerated() {
                print("   Group \(groupIndex): '\(group.dateLabel)' with \(group.messages.count) messages")
                for (msgIndex, msg) in group.messages.enumerated() {
                    print("      [\(msgIndex)] '\(msg.content)' from \(msg.senderName) at \(msg.timestamp)")
                }
            }
        }
        
        print("🔍 ===== END CHATVIEWMODEL DEBUG =====\n")
        
        // Also debug the messaging service
        messagingService.debugCurrentState()
    }
    
    func testMessageLoading() {
        Task {
            await messagingService.testMessageLoading()
        }
    }
    
    func debugChatSelection(_ chatId: UUID) {
        Task {
            await messagingService.debugConversationSelection(chatId)
        }
    }
    
    func debugSpecificMessage() {
        Task {
            await messagingService.debugSpecificMessage()
        }
    }
    
    func debugScrollToBottom() {
        print("📜 Attempting to scroll to bottom...")
        if !messageGroups.isEmpty {
            if let lastGroup = messageGroups.last,
               let lastMessage = lastGroup.messages.last {
                print("📜 Found last message: '\(lastMessage.content)' with ID: \(lastMessage.id)")
                // We can't directly scroll from here since we don't have access to ScrollViewReader
                // This method is for debugging purposes to identify the target message
            } else {
                print("📜 No last message found in groups")
            }
        } else {
            print("📜 No message groups available")
        }
    }
    
    func forceReload() {
        Task {
            print("🔄 ChatViewModel: Force reloading all data...")
            
            // Clear current data
            await MainActor.run {
                currentMessages = []
                messageGroups = []
                objectWillChange.send()
            }
            
            // Refresh messaging service data
            await messagingService.refreshAllData()
            
            // If we have a selected conversation, reload its messages
            if let conversationId = selectedChatId {
                print("🔄 ChatViewModel: Reloading messages for current conversation: \(conversationId)")
                await messagingService.selectConversation(conversationId)
            }
        }
    }
    
    deinit {
        typingTimer?.invalidate()
    }
}
