//
//  ServicesConfigurationManager.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

@MainActor
class ServicesConfigurationManager: ObservableObject {
    @Published var environment: Environment = .qa // Changed from qaDirectIP to qa
    
    enum Environment: String, CaseIterable {
        case qa = "QA"
        case qaDirectIP = "QA (Direct IP with Host Headers)"
        case qaInsecure = "QA (HTTP - Host Headers)"
        case development = "Development"
        
        var authServerUrl: String {
            switch self {
            case .qa:
                return "https://authqa.axminc.com"
            case .qaDirectIP:
                return "https://10.10.60.70"  // Uses host headers for virtual hosting
            case .qaInsecure:
                return "http://10.10.60.70"   // HTTP with host headers
            case .development:
                return "http://localhost:5229"
            }
        }
        
        var signalRHubUrl: String {
            switch self {
            case .qa:
                return "https://nsmessageserviceqa.axminc.com/messageHub"
            case .qaDirectIP:
                return "https://10.10.60.70/messageHub"  // Uses host headers
            case .qaInsecure:
                return "http://10.10.60.70/messageHub"   // HTTP with host headers
            case .development:
                return "http://localhost:5228/messageHub"
            }
        }
        
        var companyId: String {
            return "NOTHINGSOCIAL"
        }
    }
    
    static let shared = ServicesConfigurationManager()
    
    private init() {
        // Load saved environment preference
        if let savedEnvironment = UserDefaults.standard.string(forKey: "selectedEnvironment"),
           let environment = Environment(rawValue: savedEnvironment) {
            self.environment = environment
        }
    }
    
    func setEnvironment(_ environment: Environment) {
        self.environment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: "selectedEnvironment")
    }
}
