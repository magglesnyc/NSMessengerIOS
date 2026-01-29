//
//  ChatDetailView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/18/26.
//

import SwiftUI

// MARK: - All required types are now available from AppTypes.swift
// This file should compile without errors once AppTypes.swift is added to your target
// 
// INSTRUCTIONS:
// 1. Add AppTypes.swift to your Xcode project target
// 2. Make sure it's checked in Build Phases → Compile Sources
// 3. Clean build folder and rebuild
//
// AppTypes.swift contains all the missing types:
// - SelectedMedia, MediaType, MediaAttachmentDto
// - MediaService, MediaSelectionSheet
// - KeyboardManager, Spacing constants

struct ChatDetailViewV2: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var keyboardManager = KeyboardManager()
    @State private var showDebugAlert = false
    @State private var hasInitiallyScrolled = false
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with chat name and back button
            ChatDetailHeaderV2(
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
                                        .foregroundColor(.secondary)
                                    Text("No messages yet")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Text("Start the conversation!")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.secondary.opacity(0.7))
                                    
                                    #if DEBUG
                                    Button("Debug") {
                                        showDebugAlert = true
                                    }
                                    .padding(.top)
                                    .font(.system(size: 12, weight: .medium))
                                    #endif
                                }
                                Spacer()
                            } else {
                                // Message groups
                                ForEach(viewModel.messageGroups) { group in
                                    MessageGroupViewV2(group: group)
                                }
                            }
                            
                            // Typing indicator
                            if !viewModel.typingUsers.isEmpty {
                                TypingIndicatorViewV2(typingUsers: Array(viewModel.typingUsers))
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
                        // Scroll to bottom whenever messages change
                        if !groups.isEmpty {
                            // Use longer delay for initial scroll to ensure messages are rendered
                            let delay = hasInitiallyScrolled ? 0.2 : 0.5
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                if hasInitiallyScrolled {
                                    scrollToBottomSmoothly(proxy: proxy)
                                } else {
                                    scrollToBottomInstantly(proxy: proxy)
                                    hasInitiallyScrolled = true
                                }
                            }
                        }
                    }
                    .onReceive(viewModel.$shouldScrollToBottom) { shouldScroll in
                        // React to scroll commands from the view model
                        if shouldScroll && !viewModel.messageGroups.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                    MessageInputViewV2(
                        messageText: $viewModel.messageText,
                        onSend: {
                            viewModel.sendMessage()
                            // The scroll will be triggered by the viewModel automatically
                        },
                        onSendWithMedia: { attachments in
                            viewModel.sendMessageWithMedia(attachments: attachments)
                        },
                        onTextChanged: viewModel.onMessageTextChanged
                    )
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .keyboardSafe() // Use the gentler keyboard handling
        .environmentObject(keyboardManager)
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
        
        print("📜 Scrolling to bottom instantly for chat: \(selectedChatName)")
        
        // Multiple attempts with different scroll targets for maximum reliability
        if let lastGroup = viewModel.messageGroups.last,
           let lastMessage = lastGroup.messages.last {
            
            // Immediate scroll to last message
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
            
            // Backup scroll attempts with delays
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            
            // Final attempt after UI settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
        
        hasInitiallyScrolled = true
    }
    
    // Smooth animated scroll (for new messages and keyboard events)
    private func scrollToBottomSmoothly(proxy: ScrollViewProxy) {
        guard !viewModel.messageGroups.isEmpty else {
            print("📜 No messages to scroll to")
            return
        }
        
        print("📜 Scrolling to bottom smoothly for new messages")
        
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastGroup = viewModel.messageGroups.last,
               let lastMessage = lastGroup.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private var selectedChatName: String {
        guard let selectedChatId = viewModel.selectedChatId else { return "Chat" }
        return viewModel.chats.first { $0.conversationId == selectedChatId }?.name ?? "Chat"
    }
}

struct ChatDetailHeaderV2: View {
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                    
                    Text(chatName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                #endif
                
                // Refresh button
                if let onRefreshTap = onRefreshTap {
                    Button(action: onRefreshTap) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct MessageGroupViewV2: View {
    let group: MessageGroup
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Date label
            Text(group.dateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.md)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Messages
            ForEach(group.messages) { message in
                MessageBubbleViewV2(message: message)
                    .id(message.id)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

struct MessageBubbleViewV2: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.isFromCurrentUser {
                Spacer()
                
                // Timestamp on left for current user messages
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        message.isFromCurrentUser ? Color.accentColor : Color(.systemGray5)
                    )
                    .cornerRadius(16)
            }
            
            if !message.isFromCurrentUser {
                // Timestamp on right for other users' messages
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.7))
                
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
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageInputViewV2: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let onSendWithMedia: ([MediaAttachmentDto]) -> Void
    let onTextChanged: (String) -> Void
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var keyboardManager: KeyboardManager
    
    @State private var showingMediaPicker = false
    @State private var selectedMedia: [SelectedMedia] = []
    @State private var isUploadingMedia = false
    @StateObject private var mediaService = MediaService.shared
    
    private func sendMessage() {
        if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
            onSend()
            // Keep focus to maintain keyboard for continued conversation
            isTextFieldFocused = true
        }
    }
    
    private func sendMessageWithMedia() {
        guard !selectedMedia.isEmpty else {
            sendMessage()
            return
        }
        
        isUploadingMedia = true
        
        Task {
            do {
                let attachments = try await mediaService.uploadMultipleMedia(selectedMedia)
                
                await MainActor.run {
                    onSendWithMedia(attachments)
                    selectedMedia.removeAll()
                    isUploadingMedia = false
                    isTextFieldFocused = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to upload media: \(error)")
                    isUploadingMedia = false
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Media preview section
            if !selectedMedia.isEmpty {
                MediaPreviewViewV2(selectedMedia: $selectedMedia) { media in
                    selectedMedia.removeAll { $0.id == media.id }
                }
            }
            
            HStack(spacing: Spacing.md) {
                // Paperclip button
                Button(action: {
                    showingMediaPicker = true
                }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .disabled(isUploadingMedia)
                
                HStack {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .tint(.accentColor)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                        .onSubmit {
                            if selectedMedia.isEmpty {
                                sendMessage()
                            } else {
                                sendMessageWithMedia()
                            }
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
                    
                    if !messageText.isEmpty || !selectedMedia.isEmpty {
                        Button(action: {
                            if selectedMedia.isEmpty {
                                sendMessage()
                            } else {
                                sendMessageWithMedia()
                            }
                        }) {
                            if isUploadingMedia {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .disabled(isUploadingMedia)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .padding(.bottom, keyboardManager.isKeyboardVisible ? 0 : 0) // Let the safe area handle bottom padding
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaSelectionSheet(isPresented: $showingMediaPicker) { media in
                selectedMedia.append(contentsOf: media)
            }
        }
    }
}

struct TypingIndicatorViewV2: View {
    let typingUsers: [UUID]
    @State private var animationScale: Double = 1.0
    
    var body: some View {
        HStack {
            Text("Someone is typing...")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
            
            // Animated dots
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
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
    ChatDetailViewV2(viewModel: ChatViewModel())
}

struct MediaPreviewViewV2: View {
    @Binding var selectedMedia: [SelectedMedia]
    let onRemove: (SelectedMedia) -> Void
    
    var body: some View {
        if !selectedMedia.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(selectedMedia) { media in
                        MediaPreviewItemV2(media: media) {
                            onRemove(media)
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }
            .frame(height: 80)
            .background(Color(.systemGray6))
        }
    }
}

struct MediaPreviewItemV2: View {
    let media: SelectedMedia
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 60, height: 60)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: iconForMediaType(media.mediaType))
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        
                        Text(media.fileName.prefix(8) + "...")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                )
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .offset(x: 5, y: -5)
        }
    }
    
    private func iconForMediaType(_ type: MediaType) -> String {
        switch type {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .document:
            return "doc"
        }
    }
}

