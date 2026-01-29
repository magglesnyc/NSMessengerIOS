//
//  ChatDetailView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/18/26.
//

import SwiftUI

struct ChatDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyboardManager = KeyboardManager()
    @State private var showDebugAlert = false
    @State private var hasInitiallyScrolled = false
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with chat name and back button
            ChatDetailHeader(
                chatName: selectedChatName,
                onBackTap: {
                    presentationMode.wrappedValue.dismiss()
                },
                onRefreshTap: {
                    Task {
                        await viewModel.refreshMessages()
                    }
                },
                onDebugTap: {
                    viewModel.debugConnection()
                }
            )
            
            // Messages area
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: Spacing.lg) {
                            if viewModel.messageGroups.isEmpty {
                                // Empty state
                                Spacer()
                                VStack(spacing: Spacing.md) {
                                    Image(systemName: "message")
                                        .font(.largeTitle)
                                        .foregroundColor(.textSecondary)
                                    Text("No messages yet")
                                        .font(.lato(16, weight: .regular))
                                        .foregroundColor(.textSecondary)
                                    Text("Start the conversation!")
                                        .font(.lato(14, weight: .regular))
                                        .foregroundColor(.textTertiary)
                                    
                                    #if DEBUG
                                    Button("Debug") {
                                        showDebugAlert = true
                                    }
                                    .padding(.top)
                                    .font(.lato(12, weight: .medium))
                                    #endif
                                }
                                Spacer()
                            } else {
                                // Message groups
                                ForEach(viewModel.messageGroups) { group in
                                    MessageGroupView(group: group)
                                }
                            }
                            
                            // Typing indicator
                            if !viewModel.typingUsers.isEmpty {
                                TypingIndicatorView(typingUsers: Array(viewModel.typingUsers))
                                    .padding(.horizontal, Spacing.lg)
                            }
                            
                            // Bottom spacer to act as scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.vertical, Spacing.lg)
                        .padding(.bottom, keyboardManager.isKeyboardVisible ? 20 : 0) // Extra padding when keyboard is visible
                    }
                    .refreshable {
                        // Pull to refresh - reload messages
                        await viewModel.refreshMessages()
                    }

                    .onChange(of: viewModel.selectedChatId) { _ in
                        // Reset scroll state when chat changes
                        hasInitiallyScrolled = false
                        
                        // Immediately position at bottom when switching chats
                        if !viewModel.messageGroups.isEmpty {
                            DispatchQueue.main.async {
                                scrollToBottomInstantly(proxy: proxy)
                                hasInitiallyScrolled = true
                            }
                        }
                    }
                    .onChange(of: keyboardManager.isKeyboardVisible) { isVisible in
                        // When keyboard shows, scroll to bottom to keep last message visible
                        if isVisible && hasInitiallyScrolled && !viewModel.messageGroups.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                scrollToBottomSmoothly(proxy: proxy)
                            }
                        }
                    }
                    .onAppear {
                        // Store proxy reference
                        scrollViewProxy = proxy
                    }
                    .onReceive(viewModel.$messageGroups) { groups in
                        print("📜 onReceive messageGroups: \(groups.count) groups, hasInitiallyScrolled: \(hasInitiallyScrolled)")
                        // Only scroll for new messages after initial load
                        if !groups.isEmpty && hasInitiallyScrolled {
                            print("📜 Using smooth scroll for new messages")
                            // For new messages, use smooth scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottomSmoothly(proxy: proxy)
                            }
                        } else if !groups.isEmpty && !hasInitiallyScrolled {
                            print("📜 Using instant positioning for initial load")
                            // For initial load, position instantly without animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottomInstantly(proxy: proxy)
                                hasInitiallyScrolled = true
                            }
                        }
                    }
                    .onReceive(viewModel.$shouldScrollToBottom) { shouldScroll in
                        // React to scroll commands from the view model
                        if shouldScroll && !viewModel.messageGroups.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottomSmoothly(proxy: proxy)
                            }
                        }
                    }
                    #if DEBUG
                    .onLongPressGesture {
                        showDebugAlert = true
                    }
                    #endif
                    
                    // Message input
                    MessageInputView(
                        messageText: $viewModel.messageText,
                        onSend: {
                            viewModel.sendMessage()
                            // The scroll will be triggered by the viewModel automatically
                        },
                        onTextChanged: viewModel.onMessageTextChanged
                    )
                }
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarHidden(true)
        .keyboardSafe() // Use the gentler keyboard handling
        .environmentObject(keyboardManager)
        .onAppear {
            // Reset scroll state when view appears
            hasInitiallyScrolled = false
            
            // Don't automatically scroll here - let the messageGroups receiver handle it
            // This prevents double-scrolling when switching chats
        }
        #if DEBUG
        .alert("Debug Options", isPresented: $showDebugAlert) {
            Button("Debug Connection") {
                viewModel.debugConnection()
            }
            Button("Test Message Loading") {
                viewModel.testMessageLoading()
            }
            Button("Debug Chat Selection") {
                if let chatId = viewModel.selectedChatId {
                    viewModel.debugChatSelection(chatId)
                }
            }
            Button("Debug Specific Message") {
                viewModel.debugSpecificMessage()
            }
            Button("Force Reload") {
                viewModel.forceReload()
            }
            Button("Cancel", role: .cancel) { }
        }
        #endif
    }
    
    // Instant scroll to bottom (for initial loads and chat switches)
    private func scrollToBottomInstantly(proxy: ScrollViewProxy) {
        guard !viewModel.messageGroups.isEmpty else {
            print("📜 No messages to scroll to")
            return
        }
        
        print("📜 Positioning at bottom instantly for chat: \(selectedChatName)")
        print("📜 Message groups count: \(viewModel.messageGroups.count)")
        
        // Use a transaction with disabled animations to prevent any visible scrolling
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    // Smooth scroll to bottom (for new messages and keyboard events)
    private func scrollToBottomSmoothly(proxy: ScrollViewProxy) {
        guard !viewModel.messageGroups.isEmpty else {
            print("📜 No messages to scroll to")
            return
        }
        
        print("📜 Scrolling to bottom smoothly")
        
        // Smooth animated scroll to bottom
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    private var selectedChatName: String {
        guard let selectedChatId = viewModel.selectedChatId else { return "Chat" }
        return viewModel.chats.first { $0.conversationId == selectedChatId }?.name ?? "Chat"
    }
}

struct ChatDetailHeader: View {
    let chatName: String
    let onBackTap: () -> Void
    let onRefreshTap: (() -> Void)?
    let onDebugTap: (() -> Void)?
    
    var body: some View {
        HStack {
            // Combined back button with arrow and name
            Button(action: onBackTap) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chevron.left")
                        .font(.lato(18, weight: .medium))
                        .foregroundColor(.accent)
                    
                    Text(chatName)
                        .font(.lato(18, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            HStack(spacing: Spacing.md) {
                // Debug button (only in debug builds)
                #if DEBUG
                if let onDebugTap = onDebugTap {
                    Button(action: onDebugTap) {
                        Image(systemName: "ladybug")
                            .font(.lato(16, weight: .medium))
                            .foregroundColor(.accent)
                    }
                }
                #endif
                
                // Refresh button
                if let onRefreshTap = onRefreshTap {
                    Button(action: onRefreshTap) {
                        Image(systemName: "arrow.clockwise")
                            .font(.lato(16, weight: .medium))
                            .foregroundColor(.accent)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.lato(18, weight: .medium))
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.backgroundWhite)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct MessageGroupView: View {
    let group: MessageGroup
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Date label
            Text(group.dateLabel)
                .font(.lato(12, weight: .medium))
                .foregroundColor(.textSecondary)
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.md)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            
            // Messages
            ForEach(group.messages) { message in
                MessageBubbleView(message: message)
                    .id(message.id)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.isFromCurrentUser {
                Spacer()
                
                // Timestamp on left for current user messages
                Text(formatTime(message.timestamp))
                    .font(.lato(10, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.lato(12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                
                Text(message.content)
                    .font(.lato(14, weight: .regular))
                    .foregroundColor(message.isFromCurrentUser ? .white : .textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        message.isFromCurrentUser ? Color.accent : Color.receivedMessageBubble
                    )
                    .cornerRadius(16)
            }
            
            if !message.isFromCurrentUser {
                // Timestamp on right for other users' messages
                Text(formatTime(message.timestamp))
                    .font(.lato(10, weight: .regular))
                    .foregroundColor(.textTertiary)
                
                Spacer()
            }
        }
        .onAppear {
            // Debug timestamp information when message appears
            print("🕐 MessageBubbleView: Displaying message '\(message.content)' with timestamp: \(message.timestamp)")
            print("    Formatted time: \(formatTime(message.timestamp))")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        return date.timeString() // Use the enhanced extension method
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let onTextChanged: (String) -> Void
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var keyboardManager: KeyboardManager
    
    private func sendMessage() {
        if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
            onSend()
            // Keep focus to maintain keyboard for continued conversation
            isTextFieldFocused = true
        }
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            HStack {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .font(.lato(14, weight: .regular))
                    .foregroundColor(.textPrimary)
                    .tint(.accent)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .onSubmit {
                        sendMessage()
                    }
                    .onChange(of: messageText) { newValue in
                        onTextChanged(newValue)
                    }
                    .onAppear {
                        // Auto-focus when view appears for better UX
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextFieldFocused = true
                        }
                    }
                
                if !messageText.isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.lato(16, weight: .medium))
                            .foregroundColor(.accent)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.backgroundSecondary)
            .cornerRadius(20)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .padding(.bottom, keyboardManager.isKeyboardVisible ? 0 : 0) // Let the safe area handle bottom padding
        .background(Color.backgroundWhite)
    }
}

struct TypingIndicatorView: View {
    let typingUsers: [UUID]
    @State private var animationScale: Double = 1.0
    
    var body: some View {
        HStack {
            Text("Someone is typing...")
                .font(.lato(12, weight: .regular))
                .foregroundColor(.textSecondary)
            
            // Animated dots
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.textSecondary)
                        .frame(width: 4, height: 4)
                        .scaleEffect(animationScale)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationScale
                        )
                }
            }
            
            Spacer()
        }
        .onAppear {
            animationScale = 1.5
        }
    }
}

#Preview {
    ChatDetailView(viewModel: ChatViewModel())
}
