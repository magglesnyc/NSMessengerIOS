//
//  ChatScrollManager.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import SwiftUI
import Combine

/// A specialized manager for handling chat scroll behavior
class ChatScrollManager: ObservableObject {
    @Published var shouldScrollToBottom = false
    private var keyboardManager: KeyboardManager?
    
    /// Trigger scroll to bottom with a slight delay for reliability
    func scrollToBottom(delay: Double = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.shouldScrollToBottom = true
            // Reset the flag after a short time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.shouldScrollToBottom = false
            }
        }
    }
    
    /// Handle keyboard appearance and ensure scroll position
    func handleKeyboardAppearance(with keyboardManager: KeyboardManager) {
        self.keyboardManager = keyboardManager
        // When keyboard appears, scroll to maintain message visibility
        if keyboardManager.isKeyboardVisible {
            scrollToBottom(delay: 0.3)
        }
    }
}

/// A view modifier that handles automatic scrolling for chat messages
struct ChatAutoScroll: ViewModifier {
    let scrollProxy: ScrollViewProxy?
    let messageGroups: [MessageGroup]
    @StateObject private var scrollManager = ChatScrollManager()
    @EnvironmentObject var keyboardManager: KeyboardManager
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scrollManager.shouldScrollToBottom) { shouldScroll in
                if shouldScroll, let proxy = scrollProxy {
                    performScrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: keyboardManager.isKeyboardVisible) { isVisible in
                if isVisible {
                    scrollManager.scrollToBottom(delay: 0.3)
                }
            }
            .onChange(of: messageGroups.count) { _ in
                // Auto-scroll when new message groups are added
                scrollManager.scrollToBottom()
            }
            .environmentObject(scrollManager)
    }
    
    private func performScrollToBottom(proxy: ScrollViewProxy) {
        guard !messageGroups.isEmpty else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastGroup = messageGroups.last,
               let lastMessage = lastGroup.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            } else {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

extension View {
    /// Applies automatic chat scrolling behavior
    func chatAutoScroll(
        proxy: ScrollViewProxy?,
        messageGroups: [MessageGroup]
    ) -> some View {
        self.modifier(ChatAutoScroll(
            scrollProxy: proxy,
            messageGroups: messageGroups
        ))
    }
}