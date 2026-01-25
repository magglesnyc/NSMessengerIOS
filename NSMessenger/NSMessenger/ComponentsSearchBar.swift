//
//  SearchBar.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onTextChanged: ((String) -> Void)?
    
    @State private var isEditing = false
    
    init(text: Binding<String>, placeholder: String = "Search...", onTextChanged: ((String) -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onTextChanged = onTextChanged
    }
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.textTertiary)
                    .font(.system(size: 14))
                
                TextField(placeholder, text: $text, onEditingChanged: { editing in
                    // Add a small delay to prevent constraint conflicts during rapid focus changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditing = editing
                        }
                    }
                })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.lato(11.46, weight: .regular))
                .foregroundColor(.textPrimary)
                .onChange(of: text) { oldValue, newValue in
                    onTextChanged?(newValue)
                }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onTextChanged?("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.textTertiary)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .frame(height: 30)
            .background(Color.backgroundPrimary)
            .cornerRadius(CornerRadius.standard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.standard)
                    .stroke(isEditing ? Color.primaryPurple : Color.borderColor, lineWidth: BorderWidth.thin)
            )
            
            if isEditing {
                Button("Cancel") {
                    text = ""
                    isEditing = false
                    KeyboardManager.dismissKeyboard()
                }
                .font(.bodyText)
                .foregroundColor(.primaryPurple)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

private extension View {
    func hideKeyboard() {
        KeyboardManager.dismissKeyboard()
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""), placeholder: "Search contacts...")
        SearchBar(text: .constant("Sample text"), placeholder: "Search messages...")
    }
    .padding()
    .background(Color.backgroundPrimary)
}
