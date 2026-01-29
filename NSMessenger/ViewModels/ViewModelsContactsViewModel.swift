//
//  ContactsViewModel.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var contacts: [SignalRUserDto] = []
    @Published var searchResults: [SignalRUserDto] = []
    @Published var contactRequests: [SignalRContactRequestDto] = []
    @Published var isSearching = false
    @Published var pendingContactRequests: Set<String> = []
    
    private let messagingService = MessagingService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    var filteredContacts: [SignalRUserDto] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { contact in
                contact.displayName.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var receivedContactRequests: [SignalRContactRequestDto] {
        guard let currentUserId = authService.authState.user?.userId else { return [] }
        return contactRequests.filter { request in
            request.toUserId == currentUserId.uuidString && request.status == 0  // 0 = Pending
        }
    }
    
    var unreadRequestCount: Int {
        receivedContactRequests.count
    }
    
    init() {
        observeMessagingService()
        setupSearchDebouncing()
        loadInitialData()
    }
    
    private func loadInitialData() {
        Task {
            // Ensure we have fresh data from the API
            await messagingService.refreshAllData()
        }
    }
    
    private func observeMessagingService() {
        // Observe contacts
        messagingService.$contacts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] contacts in
                self?.contacts = contacts.sorted { $0.displayName < $1.displayName }
            }
            .store(in: &cancellables)
        
        // Observe contact requests
        messagingService.$contactRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requests in
                self?.contactRequests = requests
                // Update pending requests set
                guard let currentUserId = self?.authService.authState.user?.userId.uuidString else { return }
                self?.pendingContactRequests = Set(
                    requests
                        .filter { $0.fromUserId == currentUserId && $0.status == 0 }  // 0 = Pending
                        .map { $0.toUserId }
                )
            }
            .store(in: &cancellables)
    }
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                Task { @MainActor in
                    self?.performSearch(searchText)
                }
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(_ query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("🔍 Search query is empty, clearing results")
            Task { @MainActor in
                self.searchResults = []
                self.isSearching = false
            }
            return
        }
        
        print("🔍 Performing search for: '\(query)'")
        Task { @MainActor in
            self.isSearching = true
        }
        
        searchTask = Task {
            do {
                print("🔍 Calling searchUsers API...")
                let results = await messagingService.searchUsers(query: query)
                print("🔍 Search API returned \(results.count) results")
                
                // Filter out current user and existing contacts
                let currentUserId = authService.authState.user?.userId.uuidString
                let contactIds = Set(contacts.map { $0.id })
                
                let filteredResults = results.filter { user in
                    user.id != currentUserId && !contactIds.contains(user.id)
                }
                
                print("🔍 Filtered results: \(filteredResults.count) users (removed current user and existing contacts)")
                
                await MainActor.run {
                    self.searchResults = filteredResults
                    self.isSearching = false
                    print("🔍 Search completed, UI updated with \(filteredResults.count) results")
                }
            } catch {
                print("🔍 Search failed with error: \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }
    
    func sendContactRequest(to userId: String) {
        Task { @MainActor in
            self.pendingContactRequests.insert(userId)
        }
        
        Task {
            guard let uuid = UUID(uuidString: userId) else { return }
            let success = await messagingService.sendContactRequest(to: uuid)
            if !success {
                await MainActor.run {
                    // Remove from pending if failed
                    self.pendingContactRequests.remove(userId)
                }
            }
        }
    }
    
    func acceptContactRequest(_ request: SignalRContactRequestDto) {
        Task {
            guard let requestId = UUID(uuidString: request.id) else { return }
            let success = await messagingService.respondToContactRequest(
                requestId: requestId,
                approve: true
            )
            
            if success {
                // Request will be updated via the messaging service observer
                print("Contact request accepted")
            }
        }
    }
    
    func declineContactRequest(_ request: SignalRContactRequestDto) {
        Task {
            guard let requestId = UUID(uuidString: request.id) else { return }
            let success = await messagingService.respondToContactRequest(
                requestId: requestId,
                approve: false
            )
            
            if success {
                // Request will be updated via the messaging service observer
                print("Contact request declined")
            }
        }
    }
    
    func startConversation(with contact: SignalRUserDto, onConversationCreated: @escaping (UUID) -> Void) {
        Task {
            guard let contactId = UUID(uuidString: contact.id) else { return }
            if let conversation = await messagingService.createPrivateConversation(with: contactId) {
                await MainActor.run {
                    guard let conversationId = UUID(uuidString: conversation.id) else { return }
                    onConversationCreated(conversationId)
                }
            }
        }
    }
    
    func refreshData() {
        Task {
            await messagingService.loadContacts()
            await messagingService.loadContactRequests()
        }
    }
    
    func isContactRequestPending(for userId: String) -> Bool {
        return pendingContactRequests.contains(userId)
    }
    
    deinit {
        searchTask?.cancel()
    }
}
