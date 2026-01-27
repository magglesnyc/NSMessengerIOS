//
//  DesignSystem.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import SwiftUI

// MARK: - Spacing

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Color Extensions

extension Color {
    // MARK: - Background Colors
    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let backgroundTertiary = Color(.tertiarySystemBackground)
    static let backgroundWhite = Color.white
    
    // MARK: - Text Colors
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    
    // MARK: - Accent Colors
    static let accent = Color.blue
    static let accentSecondary = Color.blue.opacity(0.7)
    
    // MARK: - Status Colors
    static let successGreen = Color.green
    static let warningYellow = Color.yellow
    static let errorRed = Color.red
    
    // MARK: - Chat Colors
    static let chatBubbleSent = Color.blue
    static let chatBubbleReceived = Color(.systemGray5)
}

// MARK: - Font Extensions

extension Font {
    // Lato font family with fallback to system font
    static func lato(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .default)
    }
}

// MARK: - View Modifiers

struct KeyboardSafeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

extension View {
    func keyboardSafe() -> some View {
        modifier(KeyboardSafeModifier())
    }
}

// MARK: - Keyboard Manager

@MainActor
class KeyboardManager: ObservableObject {
    @Published var isKeyboardVisible = false
    @Published var keyboardHeight: CGFloat = 0
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        keyboardHeight = keyboardFrame.height
        isKeyboardVisible = true
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        keyboardHeight = 0
        isKeyboardVisible = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}