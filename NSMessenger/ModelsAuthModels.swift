//
//  AuthModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import Foundation

// MARK: - Authentication Models

struct AuthenticationState: Codable {
    let isAuthenticated: Bool
    let token: String?
    let user: UserInfo?
    let tokenExpiration: Date?
    
    init(isAuthenticated: Bool, token: String?, user: UserInfo?, tokenExpiration: Date?) {
        self.isAuthenticated = isAuthenticated
        self.token = token
        self.user = user
        self.tokenExpiration = tokenExpiration
    }
}

struct UserInfo: Codable, Identifiable {
    let id: String
    let userId: UUID
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let profilePhotoUrl: String?
    let roles: [String]?
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        } else if let firstName = firstName {
            return firstName
        } else {
            return username.isEmpty ? email : username
        }
    }
    
    init(id: String, userId: UUID, username: String, email: String, firstName: String? = nil, lastName: String? = nil, profilePhotoUrl: String? = nil, roles: [String]? = nil) {
        self.id = id
        self.userId = userId
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.profilePhotoUrl = profilePhotoUrl
        self.roles = roles
    }
}

// MARK: - Login Models

struct LoginRequest: Codable {
    let username: String
    let password: String
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String?
    let errorMessage: String?
    
    init(success: Bool, token: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.token = token
        self.errorMessage = errorMessage
    }
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
    
    init(username: String, email: String, password: String, firstName: String? = nil, lastName: String? = nil) {
        self.username = username
        self.email = email
        self.password = password
        self.firstName = firstName
        self.lastName = lastName
    }
}

struct RegisterResponse: Codable {
    let success: Bool
    let userId: String?
    let errorMessage: String?
    
    init(success: Bool, userId: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.userId = userId
        self.errorMessage = errorMessage
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(String)
    case invalidToken
    case tokenExpired
    case keychainError
    case serverError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidToken:
            return "Invalid authentication token"
        case .tokenExpired:
            return "Authentication token has expired"
        case .keychainError:
            return "Failed to save authentication data"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - JWT Helper Models

struct JWTClaims: Codable {
    let sub: String     // User ID
    let username: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let roles: [String]?
    let exp: Int        // Expiration time
    let iat: Int        // Issued at time
    
    // Custom coding keys to handle different claim names
    enum CodingKeys: String, CodingKey {
        case sub
        case username = "unique_name"
        case email
        case firstName = "given_name"
        case lastName = "family_name"
        case roles = "role"
        case exp
        case iat
    }
}

// MARK: - Configuration Models

struct ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {}
    
    // Server configuration
    var baseURL: String {
        // This should be configurable, but for now use a default
        return "https://10.10.60.70:7050"
    }
    
    var signalRHubURL: String {
        return "\(baseURL)/messagingHub"
    }
}

// MARK: - JWT Helper

struct JWTHelper {
    static func isTokenExpired(_ token: String) -> Bool {
        guard let claims = extractClaims(from: token) else {
            print("❌ JWTHelper: Failed to extract claims")
            return true
        }
        
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let isExpired = claims.exp <= currentTimestamp
        
        if isExpired {
            print("⚠️ JWTHelper: Token expired. Current: \(currentTimestamp), Expiry: \(claims.exp)")
        }
        
        return isExpired
    }
    
    static func extractUserInfo(from token: String) -> UserInfo? {
        guard let claims = extractClaims(from: token) else {
            print("❌ JWTHelper: Failed to extract claims for user info")
            return nil
        }
        
        // Parse the sub claim as UUID
        guard let userId = UUID(uuidString: claims.sub) else {
            print("❌ JWTHelper: Invalid user ID format in token: \(claims.sub)")
            return nil
        }
        
        return UserInfo(
            id: claims.sub,
            userId: userId,
            username: claims.username ?? "",
            email: claims.email ?? "",
            firstName: claims.firstName,
            lastName: claims.lastName,
            roles: claims.roles
        )
    }
    
    private static func extractClaims(from token: String) -> JWTClaims? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else {
            print("❌ JWTHelper: Invalid token format")
            return nil
        }
        
        let payloadSegment = segments[1]
        
        // Add padding if needed for base64 decoding
        var paddedPayload = payloadSegment
        while paddedPayload.count % 4 != 0 {
            paddedPayload += "="
        }
        
        guard let payloadData = Data(base64Encoded: paddedPayload) else {
            print("❌ JWTHelper: Failed to decode base64 payload")
            return nil
        }
        
        do {
            let claims = try JSONDecoder().decode(JWTClaims.self, from: payloadData)
            return claims
        } catch {
            print("❌ JWTHelper: Failed to decode JWT claims: \(error)")
            return nil
        }
    }
}