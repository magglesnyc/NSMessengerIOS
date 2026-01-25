//
//  AuthModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

// MARK: - Authentication Request/Response Models

struct LoginRequest: Codable {
    let userName: String
    let password: String
    let companyId: String
}

struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let expiresAt: String
    let user: UserInfo
}

struct UserInfo: Codable {
    let id: String
    let userName: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let companyId: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let token: String
    let refreshToken: String
    let expiresAt: String
}

// MARK: - Authentication State

struct AuthState {
    let isAuthenticated: Bool
    let token: String?
    let refreshToken: String?
    let expiresAt: Date?
    let user: UserInfo?
    
    static let unauthenticated = AuthState(
        isAuthenticated: false,
        token: nil,
        refreshToken: nil,
        expiresAt: nil,
        user: nil
    )
    
    static func authenticated(
        token: String,
        refreshToken: String,
        expiresAt: Date,
        user: UserInfo
    ) -> AuthState {
        return AuthState(
            isAuthenticated: true,
            token: token,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            user: user
        )
    }
}

// MARK: - Environment Configuration

enum Environment: String, CaseIterable {
    case qa = "QA"
    case development = "Development"
    
    var authBaseURL: String {
        switch self {
        case .qa:
            return "https://authqa.axminc.com"
        case .development:
            return "http://localhost:5229"
        }
    }
    
    var signalRHubURL: String {
        switch self {
        case .qa:
            return "https://nsmessageserviceqa.axminc.com/messageHub"
        case .development:
            return "http://localhost:5228/messageHub"
        }
    }
    
    var companyId: String {
        return "NOTHINGSOCIAL"
    }
}