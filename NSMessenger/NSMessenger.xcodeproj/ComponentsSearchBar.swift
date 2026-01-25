//
//  SearchBar.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    let placeholder: String
    let onCommit: (() -> Void)?
    
    init(text: Binding<String>, placeholder: String = "Search", onCommit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                    .font(.system(size: Sizes.iconMedium))
                
                TextField(placeholder, text: $text, onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                        isEditing = editing
                    }
                }, onCommit: {
                    onCommit?()
                })
                .font(.input)
                .foregroundColor(.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                            .font(.system(size: Sizes.iconMedium))
                    }
                }
            }
            .padding(.horizontal, Spacing.inputPadding)
            .padding(.vertical, Spacing.xs)
            .background(Color.searchBackground)
            .cornerRadius(CornerRadius.input)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.input)
                    .stroke(isEditing ? Color.borderActive : Color.searchBorder, lineWidth: 1)
            )
            
            if isEditing {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                        isEditing = false
                        text = ""
                        hideKeyboard()
                    }
                }
                .font(.input)
                .foregroundColor(.primaryPurple)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Specialized Search Bars

struct ContactSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    var body: some View {
        SearchBar(
            text: $searchText,
            placeholder: "Search contacts...",
            onCommit: {
                isSearching = true
            }
        )
        .onChange(of: searchText) { newValue in
            isSearching = !newValue.isEmpty
        }
    }
}

struct MessageSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        SearchBar(
            text: $searchText,
            placeholder: "Search messages..."
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""))
        
        SearchBar(text: .constant("Sample search text"))
        
        ContactSearchBar(
            searchText: .constant(""),
            isSearching: .constant(false)
        )
        
        MessageSearchBar(searchText: .constant(""))
    }
    .padding()
}