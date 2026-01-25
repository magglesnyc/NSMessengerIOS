//
//  MessagingService.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

// Type aliases to resolve ambiguity and improve readability
typealias SignalRContactRequest = SignalRContactRequestDto
typealias SignalRUser = SignalRUserDto

class MessagingService: ObservableObject {
    @Published var chats: [ChatItemDto] = []
    @Published var contacts: [SignalRUser] = []
    @Published var contactRequests: [SignalRContactRequest] = []
    @Published var conversations: [ConversationDto] = []
    @Published var currentMessages: [MessageDto] = []
    @Published var typingUsers: Set<UUID> = []
    
    private let signalRService = SignalRService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentConversationId: UUID?
    private var isInitializing = false
    
    static let shared = MessagingService()
    
    private init() {
        setupSignalRHandlers()
        observeAuthState()
        setupReconnectionHandler()
    }
    
    // MARK: - Initialization
    
    private func observeAuthState() {
        authService.$authState
            .sink { [weak self] authState in
                if authState.isAuthenticated {
                    Task {
                        await self?.initializeConnection()
                    }
                } else {
                    self?.disconnect()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupReconnectionHandler() {
        NotificationCenter.default.addObserver(
            forName: .signalRReconnected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 SignalR reconnected - re-registering event handlers")
            self?.setupSignalRHandlers()
            
            // Reload current conversation messages if we have one selected
            if let conversationId = self?.currentConversationId {
                Task {
                    await self?.loadMessages(for: conversationId)
                }
            }
        }
    }
    
    private func initializeConnection() async {
        // Prevent multiple concurrent initialization attempts
        guard !isInitializing else {
            print("🔗 Connection initialization already in progress, skipping...")
            return
        }
        
        // If already connected, just load data
        if signalRService.isConnected {
            print("✅ SignalR already connected, loading data only...")
            await loadInitialData()
            return
        }
        
        isInitializing = true
        defer { isInitializing = false }
        
        print("🔗 Initializing messaging connection...")
        do {
            try await signalRService.connect()
            print("✅ SignalR connected successfully")
            
            await setupUser()
            print("✅ User setup completed")
            
            await loadInitialData()
            print("✅ Initial data loading completed")
        } catch {
            print("❌ Failed to initialize messaging connection: \(error)")
        }
    }
    
    private func disconnect() {
        isInitializing = false
        signalRService.disconnect()
        clearData()
    }
    
    private func clearData() {
        chats = []
        contacts = []
        contactRequests = []
        conversations = []
        currentMessages = []
        typingUsers = []
        currentConversationId = nil
    }
    
    // MARK: - User Setup
    
    private func setupUser() async {
        guard let user = authService.authState.user else { return }
        
        do {
            // Create or get user profile
            let _: SignalRUserDto? = try await signalRService.createUser(
                userId: user.userId,
                username: user.email,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName
            )
            
            print("User setup completed for: \(user.email)")
        } catch {
            print("Failed to setup user: \(error)")
        }
    }
    
    // MARK: - Public Methods for Manual Data Refresh
    
    func refreshAllData() async {
        print("🔄 Manually refreshing all data...")
        guard authService.authState.isAuthenticated else {
            print("❌ Cannot refresh data - user not authenticated")
            return
        }
        
        // Ensure connection is established
        if !signalRService.isConnected {
            print("🔗 SignalR not connected, attempting to connect...")
            await initializeConnection()
        } else {
            print("✅ SignalR already connected, loading data...")
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        guard let userId = authService.authState.user?.userId else {
            print("❌ No user ID available for loading initial data")
            return
        }
        
        print("📊 Loading initial data for user: \(userId)")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                print("🔄 Loading contacts...")
                await self.loadContacts()
            }
            group.addTask {
                print("🔄 Loading contact requests...")
                await self.loadContactRequests()
            }
            group.addTask {
                print("🔄 Loading chats...")
                await self.loadChats()
            }
        }
        
        // Print summary after loading
        await MainActor.run {
            print("📊 Initial data loading completed:")
            print("   📇 Contacts: \(self.contacts.count)")
            print("   📩 Contact Requests: \(self.contactRequests.count)")
            print("   💬 Chats: \(self.chats.count)")
        }
    }
    
    func loadContacts() async {
        guard let userId = authService.authState.user?.userId else {
            print("No user ID available for loading contacts")
            return
        }
        
        print("Loading contacts for user: \(userId)")
        
        do {
            let contactsResult = try await signalRService.getContacts(userId: userId)
            
            print("Contacts loaded successfully: \(contactsResult?.count ?? 0) contacts")
            
            await MainActor.run {
                self.contacts = contactsResult ?? []
                print("Contacts updated in main actor: \(self.contacts.count)")
            }
        } catch {
            print("Failed to load contacts: \(error)")
        }
    }
    
    func loadContactRequests() async {
        guard let userId = authService.authState.user?.userId else {
            print("No user ID available for loading contact requests")
            return
        }
        
        print("Loading contact requests for user: \(userId)")
        
        do {
            let requestsResult = try await signalRService.getContactRequests(
                userId: userId,
                includeSent: true,
                includeReceived: true
            )
            
            print("Contact requests loaded successfully: \(requestsResult?.count ?? 0) requests")
            if let requests = requestsResult {
                for request in requests {
                    print("  📩 Request: from \(request.fromUserId) to \(request.toUserId), status: \(request.status)")
                }
            }
            
            await MainActor.run {
                self.contactRequests = requestsResult ?? []
            }
        } catch {
            print("Failed to load contact requests: \(error)")
        }
    }
    
    func loadChats() async {
        guard let userId = authService.authState.user?.userId else {
            print("No user ID available for loading chats")
            return
        }
        
        print("Loading chats for user: \(userId)")
        
        do {
            let signalRChats = try await signalRService.getChatsForUser(userId: userId)
            let chatsResult = signalRChats?.compactMap { signalRChat in
                let conversationId = UUID(uuidString: signalRChat.conversationId) ?? UUID()
                return ChatItemDto(
                    conversationId: conversationId,
                    name: signalRChat.title ?? "Unknown Chat",
                    photoUrl: "", // TODO: Handle photo URL mapping based on conversation type
                    lastMessage: signalRChat.displayMessage,
                    lastMessageTime: signalRChat.lastMessageDate?.formatted() ?? "",
                    unreadCount: signalRChat.unreadCount,
                    isPinned: false, // TODO: Handle pinned status - may need server support
                    isGroup: signalRChat.type == "GroupChat",
                    status: "online", // TODO: Handle status mapping - may need participant data
                    otherUserId: nil // TODO: Handle other user ID for direct messages - may need participant data
                )
            }
            
            print("Chats loaded successfully: \(chatsResult?.count ?? 0) chats")
            
            await MainActor.run {
                self.chats = chatsResult ?? []
                print("Chats updated in main actor: \(self.chats.count)")
            }
        } catch {
            print("Failed to load chats: \(error)")
        }
    }
    
    // MARK: - Contact Management
    
    func searchUsers(query: String) async -> [SignalRUser] {
        guard let userId = authService.authState.user?.userId,
              !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("🔍 SearchUsers: Invalid parameters - userId: \(authService.authState.user?.userId.uuidString ?? "nil"), query: '\(query)'")
            return []
        }
        
        print("🔍 SearchUsers: Searching for '\(query)' from user: \(userId)")
        
        do {
            let results = try await signalRService.searchUsers(
                requestingUserId: userId,
                searchQuery: query,
                maxResults: 20
            )
            
            let userCount = results?.count ?? 0
            print("🔍 SearchUsers: SignalR returned \(userCount) users")
            
            if let users = results {
                for user in users {
                    print("   👤 Found user: \(user.displayName) (\(user.email))")
                }
            }
            
            return results ?? []
        } catch {
            print("🔍 SearchUsers: Failed with error: \(error)")
            return []
        }
    }
    
    func sendContactRequest(to userId: UUID) async -> Bool {
        guard let currentUserId = authService.authState.user?.userId else { return false }
        
        do {
            let result = try await signalRService.sendContactRequest(
                fromUserId: currentUserId,
                toUserId: userId
            )
            
            return result?.success ?? false
        } catch {
            print("Failed to send contact request: \(error)")
            return false
        }
    }
    
    func respondToContactRequest(requestId: UUID, approve: Bool) async -> Bool {
        guard let userId = authService.authState.user?.userId else { return false }
        
        do {
            let result = try await signalRService.respondToContactRequest(
                requestId: requestId,
                respondingUserId: userId,
                approve: approve
            )
            
            if result?.success == true {
                // Refresh contact requests and contacts
                await loadContactRequests()
                if approve {
                    await loadContacts()
                }
            }
            
            return result?.success ?? false
        } catch {
            print("Failed to respond to contact request: \(error)")
            return false
        }
    }
    
    // MARK: - Conversation Management
    
    func createPrivateConversation(with userId: UUID) async -> ConversationDto? {
        guard let currentUserId = authService.authState.user?.userId else { return nil }
        
        do {
            let conversation: SignalRConversationDto? = try await signalRService.createConversation(
                type: "private",
                title: nil,
                participantIds: [currentUserId, userId]
            )
            
            // Convert SignalRConversationDto to ConversationDto
            if let signalRConversation = conversation {
                return ConversationDto(
                    id: signalRConversation.id,
                    title: signalRConversation.title,
                    type: signalRConversation.type,
                    participantIds: signalRConversation.participantIds,
                    createdDate: signalRConversation.createdDate
                )
            }
            
            return nil
        } catch {
            print("Failed to create conversation: \(error)")
            return nil
        }
    }
    
    func selectConversation(_ conversationId: UUID) async {
        print("🎯 Selecting conversation: \(conversationId)")
        
        // Leave current conversation if any
        if let currentId = currentConversationId {
            print("👋 Leaving current conversation: \(currentId)")
            await leaveConversation(currentId)
        }
        
        // IMPORTANT: Set current conversation ID BEFORE loading messages
        // This prevents the guard clause in loadMessages from blocking the load
        currentConversationId = conversationId
        print("✅ Set currentConversationId to: \(conversationId)")
        
        // Clear existing messages first to avoid confusion
        await MainActor.run {
            self.currentMessages = []
            self.objectWillChange.send()
        }
        
        // Join new conversation
        print("🚪 Joining conversation: \(conversationId)")
        await joinConversation(conversationId)
        
        // Load messages for the conversation
        print("📥 Loading messages for conversation: \(conversationId)")
        await loadMessages(for: conversationId)
        
        // Mark conversation as read (reset unread count)
        await MainActor.run {
            if let chatIndex = self.chats.firstIndex(where: { $0.conversationId == conversationId }) {
                let existingChat = self.chats[chatIndex]
                let updatedChat = ChatItemDto(
                    conversationId: existingChat.conversationId,
                    name: existingChat.name,
                    photoUrl: existingChat.photoUrl,
                    lastMessage: existingChat.lastMessage,
                    lastMessageTime: existingChat.lastMessageTime,
                    unreadCount: 0, // Reset unread count
                    isPinned: existingChat.isPinned,
                    isGroup: existingChat.isGroup,
                    status: existingChat.status,
                    otherUserId: existingChat.otherUserId
                )
                self.chats[chatIndex] = updatedChat
                print("📝 Reset unread count for conversation")
            }
        }
        
        print("✅ Selected conversation completed: \(conversationId)")
    }
    
    private func joinConversation(_ conversationId: UUID) async {
        do {
            try await signalRService.joinConversation(conversationId: conversationId)
            print("Joined conversation: \(conversationId)")
        } catch {
            print("Failed to join conversation: \(error)")
        }
    }
    
    private func leaveConversation(_ conversationId: UUID) async {
        do {
            try await signalRService.leaveConversation(conversationId: conversationId)
            print("Left conversation: \(conversationId)")
        } catch {
            print("Failed to leave conversation: \(error)")
        }
    }
    
    // MARK: - Message Management
    
    func loadMessages(for conversationId: UUID) async {
        print("📥 Starting to load messages for conversation: \(conversationId)")
        print("📥 Current conversation ID: \(String(describing: currentConversationId))")
        
        do {
            let signalRMessages = try await signalRService.getMessagesForConversation(conversationId: conversationId)
            
            print("📥 Received \(signalRMessages?.count ?? 0) messages from server")
            
            // Convert SignalRMessageDto to MessageDto with enhanced logging
            let messages = signalRMessages?.compactMap { signalRMessage -> MessageDto? in
                print("📥 Processing message from server:")
                print("   ID: \(signalRMessage.id)")
                print("   Server sentAt: '\(signalRMessage.sentAt)'")
                
                // Test date parsing
                let parsedDate = Date.fromServerTimestamp(signalRMessage.sentAt)
                print("   Parsed sentDate: \(parsedDate)")
                print("   Time since now: \(Date().timeIntervalSince(parsedDate)) seconds")
                print("   Content: '\(signalRMessage.content)'")
                print("   Sender: '\(signalRMessage.senderName)'")
                print("   Sender ID: '\(signalRMessage.senderId)'")
                
                // More lenient validation - only skip truly empty/invalid messages
                let trimmedContent = signalRMessage.content.trimmingCharacters(in: .whitespaces)
                if trimmedContent.isEmpty {
                    print("⚠️ Skipping message with empty content")
                    return nil
                }
                
                if signalRMessage.senderId.trimmingCharacters(in: .whitespaces).isEmpty {
                    print("⚠️ Skipping message with empty sender ID")
                    return nil
                }
                
                let messageDto = MessageDto(from: signalRMessage)
                print("✅ Created MessageDto with content: '\(messageDto.content)'")
                return messageDto
            } ?? []
            
            // Sort messages by date (oldest first)
            let sortedMessages = messages.sorted { $0.sentDate < $1.sentDate }
            
            // Update on main thread
            await MainActor.run {
                // Only update if this is still the current conversation or if we're setting it as current
                if conversationId == self.currentConversationId {
                    let previousCount = self.currentMessages.count
                    self.currentMessages = sortedMessages
                    let newCount = self.currentMessages.count
                    
                    print("📥 Updated currentMessages: \(previousCount) → \(newCount)")
                    print("📥 Current conversation: \(String(describing: self.currentConversationId))")
                    print("📥 Conversation matches: \(conversationId == self.currentConversationId)")
                    
                    // Log all loaded messages for debugging
                    for (index, message) in self.currentMessages.enumerated() {
                        let timeAgo = Date().timeIntervalSince(message.sentDate)
                        print("   Message \(index): '\(message.content)' sent \(Int(timeAgo))s ago by \(message.senderDisplayName)")
                    }
                    
                    // Force update notification
                    self.objectWillChange.send()
                    print("📥 Sent objectWillChange notification")
                } else {
                    print("⚠️ Loaded messages for different conversation (\(conversationId)) than current (\(String(describing: self.currentConversationId))), discarding")
                }
            }
        } catch {
            print("❌ Failed to load messages for conversation \(conversationId): \(error)")
            
            // Clear messages on error to avoid showing stale data, but only if this is the current conversation
            await MainActor.run {
                if conversationId == self.currentConversationId {
                    self.currentMessages = []
                    self.objectWillChange.send()
                    print("🧹 Cleared messages due to load error")
                }
            }
        }
    }
    
    func sendMessage(_ content: String, to conversationId: UUID) async -> Bool {
        guard let userId = authService.authState.user?.userId,
              !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("❌ SendMessage failed: Invalid userId or empty content")
            return false
        }
        
        print("📤 Sending message to conversation: \(conversationId), content: \(content)")
        print("📤 Current conversation ID: \(String(describing: currentConversationId))")
        print("📤 Conversation matches current: \(conversationId == currentConversationId)")
        
        // Create optimistic message for immediate UI update
        let now = Date()
        let optimisticMessage = MessageDto(
            id: String(Int.random(in: 1000000...9999999)), // Temporary ID as String
            conversationId: conversationId.uuidString,
            senderId: userId.uuidString,
            senderDisplayName: authService.authState.user?.displayName ?? "You",
            content: content,
            sentDate: now, // Use current time for optimistic message
            messageType: "Text"
        )
        
        print("📤 Created optimistic message with timestamp: \(now)")
        print("📤 Optimistic message ID: \(optimisticMessage.id)")
        print("📤 Formatted time: \(DateFormatter.messageTime.string(from: now))")
        
        // Add optimistic message immediately if it's for current conversation
        await MainActor.run {
            if conversationId == self.currentConversationId {
                let beforeCount = self.currentMessages.count
                self.currentMessages.append(optimisticMessage)
                let afterCount = self.currentMessages.count
                print("✅ Added optimistic message to UI")
                print("📊 Message count: \(beforeCount) → \(afterCount)")
                
                // Force a published update to ensure SwiftUI detects the change
                self.objectWillChange.send()
            } else {
                print("⚠️ Optimistic message not for current conversation")
                print("   Current: \(String(describing: self.currentConversationId))")
                print("   Message: \(conversationId)")
            }
        }
        
        do {
            let signalRMessage = try await signalRService.storeMessage(
                conversationId: conversationId,
                userId: userId,
                content: content
            )
            
            print("✅ Message sent successfully: \(signalRMessage != nil)")
            
            // WORKAROUND: Since server isn't broadcasting messages back via SignalR,
            // manually reload messages after successful send
            if signalRMessage != nil {
                print("🔄 Manually reloading messages after successful send...")
                
                // Remove the optimistic message first
                await MainActor.run {
                    if let optimisticIndex = self.currentMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                        self.currentMessages.remove(at: optimisticIndex)
                        print("🔄 Removed optimistic message")
                    }
                }
                
                // Reload messages from server
                await self.loadMessages(for: conversationId)
            }
            
            return signalRMessage != nil
        } catch {
            print("❌ Failed to send message: \(error)")
            
            // Remove optimistic message on failure
            await MainActor.run {
                if let optimisticIndex = self.currentMessages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.currentMessages.remove(at: optimisticIndex)
                    print("❌ Removed optimistic message due to send failure")
                }
            }
            
            return false
        }
    }
    
    // MARK: - Typing Indicators
    
    func notifyTyping(in conversationId: UUID) async {
        guard let userId = authService.authState.user?.userId else { return }
        
        do {
            try await signalRService.notifyTyping(conversationId: conversationId, userId: userId)
        } catch {
            print("Failed to notify typing: \(error)")
        }
    }
    
    func notifyStoppedTyping(in conversationId: UUID) async {
        guard let userId = authService.authState.user?.userId else { return }
        
        do {
            try await signalRService.notifyStoppedTyping(conversationId: conversationId, userId: userId)
        } catch {
            print("Failed to notify stopped typing: \(error)")
        }
    }
    
    // MARK: - SignalR Event Handlers
    
    private func setupSignalRHandlers() {
        print("🔧 Setting up SignalR event handlers...")
        
        // Clear existing handlers to avoid duplicates on reconnection
        signalRService.clearEventHandlers()
        
        // Message received - handle as SignalRMessageDto first, then convert
        signalRService.on("ReceiveMessage") { [weak self] (signalRMessage: SignalRMessageDto) in
            self?.handleReceivedMessage(signalRMessage)
        }
        
        // Try alternative event names in case server uses different naming
        signalRService.on("MessageReceived") { [weak self] (signalRMessage: SignalRMessageDto) in
            self?.handleReceivedMessage(signalRMessage)
        }
        
        signalRService.on("NewMessage") { [weak self] (signalRMessage: SignalRMessageDto) in
            self?.handleReceivedMessage(signalRMessage)
        }
        
        // Contact request received
        signalRService.on("ContactRequestReceived") { [weak self] (request: SignalRContactRequest) in
            print("📥 Received contact request from: \(request.fromUserDisplayName)")
            Task { @MainActor in
                self?.contactRequests.append(request)
            }
        }
        
        // Contact request responded to
        signalRService.on("ContactRequestResponded") { [weak self] (data: ContactRequestResponseData) in
            if let requestId = UUID(uuidString: data.requestId) {
                print("📥 Contact request \(data.approved ? "approved" : "declined"): \(requestId)")
                Task {
                    await self?.loadContactRequests()
                    if data.approved {
                        await self?.loadContacts()
                    }
                }
            }
        }
        
        // Typing notifications
        signalRService.on("UserTyping") { [weak self] (data: TypingNotificationData) in
            if let userId = UUID(uuidString: data.userId) {
                Task { @MainActor in
                    self?.typingUsers.insert(userId)
                }
            }
        }
        
        signalRService.on("UserStoppedTyping") { [weak self] (data: TypingNotificationData) in
            if let userId = UUID(uuidString: data.userId) {
                Task { @MainActor in
                    self?.typingUsers.remove(userId)
                }
            }
        }
        
        print("✅ SignalR event handlers registered successfully")
    }
    
    // MARK: - Helper Methods
    
    private func formatMessageTime(_ date: Date) -> String {
        return date.timeString()
    }
    
    private func handleReceivedMessage(_ signalRMessage: SignalRMessageDto) {
        // Convert SignalRMessageDto to MessageDto
        let message = MessageDto(from: signalRMessage)
        
        print("📥 [HANDLER] Received message: '\(message.content)' from senderId: \(message.senderId), messageId: \(message.id)")
        print("📥 [HANDLER] Message conversationId: \(message.conversationId)")
        print("📥 [HANDLER] Current conversationId: \(String(describing: self.currentConversationId))")
        print("📥 [HANDLER] Sender display name: \(message.senderDisplayName)")
        
        Task { @MainActor in
            // Only add message to currentMessages if it's for the currently selected conversation
            if let messageConversationId = UUID(uuidString: message.conversationId),
               messageConversationId == self.currentConversationId {
                
                // More precise duplicate check - only check by message ID
                let messageExists = self.currentMessages.contains { existingMessage in
                    existingMessage.id == message.id
                }
                
                if !messageExists {
                    self.currentMessages.append(message)
                    // Sort messages by sent date to ensure proper order
                    self.currentMessages.sort { $0.sentDate < $1.sentDate }
                    print("✅ [HANDLER] Added message to current conversation: \(message.content)")
                    
                    // Force UI update
                    self.objectWillChange.send()
                } else {
                    print("⚠️ [HANDLER] Message already exists (ID: \(message.id)), skipping duplicate")
                }
            } else {
                print("📝 [HANDLER] Message not for current conversation, only updating chat list")
            }
            
            // Update chat list with latest message regardless of current conversation
            if let messageConversationId = UUID(uuidString: message.conversationId),
               let chatIndex = self.chats.firstIndex(where: { $0.conversationId == messageConversationId }) {
                
                let existingChat = self.chats[chatIndex]
                
                // Update unread count if message is not for current conversation
                let newUnreadCount = messageConversationId == self.currentConversationId
                ? existingChat.unreadCount
                : existingChat.unreadCount + 1
                
                let updatedChat = ChatItemDto(
                    conversationId: existingChat.conversationId,
                    name: existingChat.name,
                    photoUrl: existingChat.photoUrl,
                    lastMessage: message.content,
                    lastMessageTime: self.formatMessageTime(message.sentDate),
                    unreadCount: newUnreadCount,
                    isPinned: existingChat.isPinned,
                    isGroup: existingChat.isGroup,
                    status: existingChat.status,
                    otherUserId: existingChat.otherUserId
                )
                
                self.chats[chatIndex] = updatedChat
                print("✅ [HANDLER] Updated chat list for conversation: \(messageConversationId)")
            } else {
                print("⚠️ [HANDLER] Could not find chat in list for conversation: \(message.conversationId)")
            }
        }
    }
    
    // MARK: - Debug/Testing Methods
    
    func testSignalRConnection() {
        print("🧪 Testing SignalR connection...")
        print("🧪 Connection state: \(signalRService.connectionState)")
        print("🧪 Is connected: \(signalRService.isConnected)")
        print("🧪 Current conversation: \(String(describing: currentConversationId))")
        print("🧪 Current messages count: \(currentMessages.count)")
        
        // Test if we can send a simple message
        Task {
            guard let conversationId = currentConversationId else {
                print("❌ No conversation selected for testing")
                return
            }
            
            let testMessage = "Test message at \(Date())"
            let success = await sendMessage(testMessage, to: conversationId)
            print("🧪 Test message sent: \(success)")
        }
    }
    
    func forceRefreshCurrentConversation() async {
        print("🔄 Force refreshing current conversation...")
        guard let conversationId = currentConversationId else {
            print("❌ No current conversation to refresh")
            return
        }
        
        // Clear existing messages first
        await MainActor.run {
            currentMessages = []
            objectWillChange.send()
        }
        
        print("🔄 Cleared existing messages, reloading...")
        
        // Reload messages
        await loadMessages(for: conversationId)
        
        print("🔄 Force refresh completed")
    }
    
    func debugCurrentState() {
        print("\n🔍 ===== DEBUG CURRENT STATE =====")
        print("   Auth state: \(authService.authState.isAuthenticated)")
        print("   User ID: \(authService.authState.user?.userId.uuidString ?? "nil")")
        print("   User display name: \(authService.authState.user?.displayName ?? "nil")")
        print("   SignalR connected: \(signalRService.isConnected)")
        print("   SignalR connection state: \(signalRService.connectionState)")
        print("   Current conversation: \(String(describing: currentConversationId))")
        print("   Messages count: \(currentMessages.count)")
        print("   Chats count: \(chats.count)")
        print("   Contacts count: \(contacts.count)")
        print("   Contact requests count: \(contactRequests.count)")
        
        if !currentMessages.isEmpty {
            print("\n📝 CURRENT MESSAGES:")
            for (index, message) in currentMessages.enumerated() {
                let timeAgo = Date().timeIntervalSince(message.sentDate)
                print("   [\(index)] ID=\(message.id)")
                print("        Content: '\(message.content)'")
                print("        Sender: \(message.senderDisplayName) (ID: \(message.senderId))")
                print("        Date: \(message.sentDate) (\(Int(timeAgo))s ago)")
                print("        Conversation: \(message.conversationId)")
            }
        } else {
            print("\n📝 NO MESSAGES IN CURRENT CONVERSATION")
        }
        
        if !chats.isEmpty {
            print("\n💬 CHATS:")
            for (index, chat) in chats.enumerated() {
                print("   [\(index)] \(chat.name)")
                print("        ID: \(chat.conversationId)")
                print("        Last message: '\(chat.lastMessage)'")
                print("        Last message time: \(chat.lastMessageTime)")
                print("        Unread count: \(chat.unreadCount)")
            }
        } else {
            print("\n💬 NO CHATS LOADED")
        }
        
        print("🔍 ===== END DEBUG STATE =====\n")
    }
    
    func testMessageLoading() async {
        print("\n🧪 ===== TESTING MESSAGE LOADING =====")
        
        guard let conversationId = currentConversationId else {
            print("❌ No conversation selected for testing")
            return
        }
        
        print("🧪 Testing message loading for conversation: \(conversationId)")
        
        // Clear current messages
        await MainActor.run {
            currentMessages = []
            objectWillChange.send()
        }
        
        print("🧪 Cleared current messages, now loading...")
        
        // Load messages directly
        await loadMessages(for: conversationId)
        
        await MainActor.run {
            print("🧪 After loading: \(currentMessages.count) messages")
            if currentMessages.isEmpty {
                print("❌ No messages loaded - potential issue with:")
                print("   - Network connectivity")
                print("   - Server response")
                print("   - Data parsing")
                print("   - Conversation ID mismatch")
            } else {
                print("✅ Messages loaded successfully")
                for (index, message) in currentMessages.enumerated() {
                    print("   [\(index)] '\(message.content)' from \(message.senderDisplayName)")
                }
            }
        }
        
        print("🧪 ===== END MESSAGE LOADING TEST =====\n")
    }
    
    func debugConversationSelection(_ conversationId: UUID) async {
        print("\n🔍 ===== DEBUG CONVERSATION SELECTION =====")
        print("🔍 About to select conversation: \(conversationId)")
        print("🔍 Current conversation before: \(String(describing: currentConversationId))")
        print("🔍 Current messages count before: \(currentMessages.count)")
        
        await selectConversation(conversationId)
        
        print("🔍 Current conversation after: \(String(describing: currentConversationId))")
        print("🔍 Current messages count after: \(currentMessages.count)")
        
        // Show detailed message info
        if !currentMessages.isEmpty {
            print("\n🔍 DETAILED MESSAGE LIST:")
            for (index, message) in currentMessages.enumerated() {
                print("   [\(index)] '\(message.content)'")
                print("        ID: \(message.id)")
                print("        From: \(message.senderDisplayName)")
                print("        Date: \(message.sentDate)")
                print("        Formatted: \(message.sentDate.timeString())")
            }
        }
        
        print("🔍 ===== END DEBUG CONVERSATION SELECTION =====\n")
    }
    
    func debugSpecificMessage() async {
        print("\n🔍 ===== DEBUG SPECIFIC MESSAGE SEARCH =====")
        guard let conversationId = currentConversationId else {
            print("❌ No conversation selected")
            return
        }
        
        // Try to get messages directly from server without any filtering
        do {
            let rawMessages = try await signalRService.getMessagesForConversation(conversationId: conversationId)
            print("🔍 Raw server response: \(rawMessages?.count ?? 0) messages")
            
            if let messages = rawMessages {
                print("\n🔍 ALL SERVER MESSAGES (chronological order):")
                let sortedMessages = messages.sorted { $0.sentAt < $1.sentAt }
                for (index, msg) in sortedMessages.enumerated() {
                    print("   [\(index)] '\(msg.content)' at \(msg.sentAt) from \(msg.senderName)")
                }
                
                // Check for the specific message you mentioned
                if let targetMessage = messages.first(where: { $0.content.contains("Did you get this Message") }) {
                    print("\n🎯 Found target message:")
                    print("   Content: '\(targetMessage.content)'")
                    print("   ID: \(targetMessage.id)")
                    print("   Date: \(targetMessage.sentAt)")
                    print("   Sender: \(targetMessage.senderName)")
                    print("   Is it the newest? \(targetMessage.id == sortedMessages.last?.id)")
                }
            }
        } catch {
            print("❌ Failed to get raw messages: \(error)")
        }
        
        print("🔍 ===== END DEBUG SPECIFIC MESSAGE SEARCH =====\n")
    }
    
    func getContactRequests(received: Bool) -> [SignalRContactRequest] {
        guard let currentUserId = authService.authState.user?.userId else { return [] }
        
        return contactRequests.filter { request in
            if received {
                return request.toUserId == currentUserId.uuidString && request.status == 0 // 0 = Pending
            } else {
                return request.fromUserId == currentUserId.uuidString && request.status == 0 // 0 = Pending
            }
        }
    }
    
}
