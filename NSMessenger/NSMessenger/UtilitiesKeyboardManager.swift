//
//  KeyboardManager.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/20/26.
//

import SwiftUI
import Combine

/// A utility class to help manage keyboard appearance and avoid constraint conflicts
class KeyboardManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
            .sink { [weak self] height in
                DispatchQueue.main.async {
                    self?.keyboardHeight = height
                    self?.isKeyboardVisible = height > 0
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.keyboardHeight = 0
                    self?.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }
    
    /// Dismisses the keyboard with a slight delay to prevent constraint conflicts
    static func dismissKeyboard() {
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    /// Shows the keyboard for a specific focus state with delay to prevent conflicts
    static func showKeyboard(delay: Double = 0.1, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
}

/// A view modifier to handle keyboard-aware layout adjustments without conflicting with system constraints
struct KeyboardAware: ViewModifier {
    @StateObject private var keyboardManager = KeyboardManager()
    let offsetWhenVisible: CGFloat
    
    init(offsetWhenVisible: CGFloat = 0) {
        self.offsetWhenVisible = offsetWhenVisible
    }
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: keyboardManager.isKeyboardVisible ? max(offsetWhenVisible, 0) : 0)
                    .animation(.easeInOut(duration: 0.25), value: keyboardManager.isKeyboardVisible)
            }
            .environmentObject(keyboardManager)
    }
}

/// A simpler keyboard-aware modifier that just adds safe bottom padding
struct KeyboardSafePadding: ViewModifier {
    @StateObject private var keyboardManager = KeyboardManager()
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: keyboardManager.isKeyboardVisible ? 20 : 0)
                    .animation(.easeInOut(duration: 0.25), value: keyboardManager.isKeyboardVisible)
            }
            .environmentObject(keyboardManager)
    }
}

extension View {
    /// Applies keyboard-aware layout adjustments to prevent constraint conflicts
    func keyboardAware(offsetWhenVisible: CGFloat = 0) -> some View {
        self.modifier(KeyboardAware(offsetWhenVisible: offsetWhenVisible))
    }
    
    /// A gentler keyboard handling that uses safe area insets instead of offsets
    func keyboardSafe() -> some View {
        self.modifier(KeyboardSafePadding())
    }
}