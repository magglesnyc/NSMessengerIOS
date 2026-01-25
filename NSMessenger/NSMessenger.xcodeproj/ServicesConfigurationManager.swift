//
//  ConfigurationManager.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

class ConfigurationManager: ObservableObject {
    @Published var currentEnvironment: Environment
    
    static let shared = ConfigurationManager()
    
    private let environmentKey = "NSMessenger_Environment"
    
    private init() {
        // Load saved environment or default to QA
        if let savedEnvironmentString = UserDefaults.standard.string(forKey: environmentKey),
           let savedEnvironment = Environment(rawValue: savedEnvironmentString) {
            self.currentEnvironment = savedEnvironment
        } else {
            self.currentEnvironment = .qa
        }
    }
    
    // MARK: - Environment Management
    
    func setEnvironment(_ environment: Environment) {
        currentEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: environmentKey)
    }
    
    // MARK: - Current Configuration Access
    
    var authBaseURL: String {
        return currentEnvironment.authBaseURL
    }
    
    var signalRHubURL: String {
        return currentEnvironment.signalRHubURL
    }
    
    var companyId: String {
        return currentEnvironment.companyId
    }
    
    // MARK: - URL Construction
    
    func authURL(for endpoint: String) -> String {
        return "\(authBaseURL)/api/Auth/\(endpoint)"
    }
    
    var loginURL: String {
        return authURL(for: "Login")
    }
    
    var refreshTokenURL: String {
        return authURL(for: "RefreshToken")
    }
    
    // MARK: - Debug Information
    
    var debugDescription: String {
        return """
        Current Environment: \(currentEnvironment.rawValue)
        Auth Base URL: \(authBaseURL)
        SignalR Hub URL: \(signalRHubURL)
        Company ID: \(companyId)
        """
    }
}