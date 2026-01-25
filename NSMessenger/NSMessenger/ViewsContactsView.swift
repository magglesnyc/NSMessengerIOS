//
//  ContactsView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var showingContactRequests = false
    
    let onStartConversation: (UUID) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(
                text: $viewModel.searchText,
                placeholder: "Search contacts or find new users...",
                onTextChanged: { _ in }
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Contact requests section
                    if viewModel.unreadRequestCount > 0 {
                        ContactRequestsSection(
                            requestCount: viewModel.unreadRequestCount,
                            onTap: { showingContactRequests = true }
                        )
                        .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Search results section
                    if !viewModel.searchText.isEmpty {
                        SearchResultsSection(viewModel: viewModel)
                            .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Contacts section
                    if !viewModel.filteredContacts.isEmpty {
                        ContactsSection(
                            contacts: viewModel.filteredContacts,
                            onStartConversation: { contact in
                                viewModel.startConversation(with: contact) { conversationId in
                                    onStartConversation(conversationId)
                                }
                            }
                        )
                        .padding(.horizontal, Spacing.lg)
                    }
                    
                    // Empty state
                    if viewModel.contacts.isEmpty && viewModel.searchText.isEmpty {
                        EmptyContactsView()
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
        }
        .refreshable {
            viewModel.refreshData()
        }
        .sheet(isPresented: $showingContactRequests) {
            ContactRequestsSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}

struct ContactRequestsSection: View {
    let requestCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.primaryPurple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact Requests")
                        .font(.lato(14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("\(requestCount) pending request\(requestCount > 1 ? "s" : "")")
                        .font(.lato(12, weight: .regular))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Text("\(requestCount)")
                    .font(.lato(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primaryPurple)
                    .cornerRadius(10)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.backgroundWhite)
        .cornerRadius(CornerRadius.medium)
        .cardShadow()
    }
}

struct SearchResultsSection: View {
    @ObservedObject var viewModel: ContactsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("SEARCH RESULTS")
                .font(.lato(12, weight: .bold))
                .foregroundColor(.primaryPurple)
                .textCase(.uppercase)
            
            if viewModel.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.bodyText)
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, Spacing.xl)
            } else if viewModel.searchResults.isEmpty {
                Text("No users found for '\(viewModel.searchText)'")
                    .font(.bodyText)
                    .foregroundColor(.textTertiary)
                    .padding(.vertical, Spacing.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { user in
                        SearchResultItem(
                            user: user,
                            isPending: viewModel.isContactRequestPending(for: user.id),
                            onAddContact: {
                                viewModel.sendContactRequest(to: user.id)
                            }
                        )
                        
                        if user.id != viewModel.searchResults.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color.backgroundWhite)
                .cornerRadius(CornerRadius.medium)
                .cardShadow()
            }
        }
    }
}

struct SearchResultItem: View {
    let user: SignalRUserDto
    let isPending: Bool
    let onAddContact: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(
                imageURL: nil, // SignalRUserDto doesn't have profilePhotoUrl
                size: 40,
                showStatus: true,
                status: user.isOnline == true ? .available : .offline
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.lato(14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(user.email)
                    .font(.lato(11, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
            
            if isPending {
                Text("PENDING")
                    .font(.lato(10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.disabledGray)
                    .cornerRadius(4)
            } else {
                Button("ADD", action: onAddContact)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

struct ContactsSection: View {
    let contacts: [SignalRUserDto]
    let onStartConversation: (SignalRUserDto) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("CONTACTS")
                .font(.lato(12, weight: .bold))
                .foregroundColor(.primaryPurple)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                ForEach(contacts) { contact in
                    ContactListItem(
                        contact: contact,
                        onTap: { },
                        onDoubleTap: { onStartConversation(contact) }
                    )
                    
                    if contact.id != contacts.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.backgroundWhite)
            .cornerRadius(CornerRadius.medium)
            .cardShadow()
        }
    }
}

struct ContactListItem: View {
    let contact: SignalRUserDto
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                AvatarView(
                    imageURL: nil, // SignalRUserDto doesn't have profilePhotoUrl
                    size: 40,
                    showStatus: true,
                    status: contact.isOnline == true ? .available : .offline
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.lato(14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(contact.isOnline == true ? "Online" : "Offline")
                        .font(.lato(11, weight: .regular))
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
    }
}

struct ContactRequestsSheet: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.receivedContactRequests.isEmpty {
                    VStack(spacing: Spacing.lg) {
                        Spacer()
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.textTertiary)
                        
                        Text("No pending requests")
                            .font(.h6)
                            .foregroundColor(.textSecondary)
                        
                        Text("Contact requests will appear here")
                            .font(.bodyText)
                            .foregroundColor(.textTertiary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xxl)
                } else {
                    List {
                        ForEach(viewModel.receivedContactRequests) { request in
                            ContactRequestRow(
                                request: request,
                                onAccept: { viewModel.acceptContactRequest(request) },
                                onDecline: { viewModel.declineContactRequest(request) }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Contact Requests")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

struct ContactRequestRow: View {
    let request: SignalRContactRequestDto
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                AvatarView(
                    imageURL: nil, // SignalRContactRequestDto doesn't have photo URL
                    size: 48,
                    showStatus: false
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.fromUserDisplayName)
                        .font(.lato(14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("wants to connect with you")
                        .font(.lato(12, weight: .regular))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: Spacing.md) {
                Button("Accept", action: onAccept)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                
                Button("Decline", action: onDecline)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

struct EmptyContactsView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)
            
            Text("No contacts yet")
                .font(.h6)
                .foregroundColor(.textSecondary)
            
            Text("Search for users to add as contacts and start messaging")
                .font(.bodyText)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, Spacing.xxl)
    }
}

#Preview {
    ContactsView { conversationId in
        print("Start conversation: \(conversationId)")
    }
}
