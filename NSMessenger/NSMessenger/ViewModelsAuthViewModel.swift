//
//  AuthViewModel.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe auth state changes
        authService.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                self?.isAuthenticated = authState.isAuthenticated
                if authState.isAuthenticated {
                    self?.errorMessage = ""
                }
            }
            .store(in: &cancellables)
        
        // Check for existing authentication
        authService.checkExistingAuthentication()
    }
    
    func login() async {
        guard !username.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both username and password"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let success = try await authService.login(username: username, password: password)
            if success {
                // Clear form
                username = ""
                password = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        authService.logout()
        username = ""
        password = ""
        errorMessage = ""
    }
}