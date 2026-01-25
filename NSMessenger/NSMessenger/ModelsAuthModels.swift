//
//  AuthModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

// MARK: - Auth Models

struct LoginRequest: Codable {
    let companyId: String
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String?
    let errorMessage: String?
    let user: UserInfo?
}

struct UserInfo: Codable {
    let userId: UUID
    let email: String
    let firstName: String?
    let lastName: String?
    
    var displayName: String {
        if let firstName = firstName, !firstName.isEmpty {
            let lastName = lastName ?? ""
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        return email
    }
}

struct AuthenticationState {
    let isAuthenticated: Bool
    let token: String?
    let user: UserInfo?
    let tokenExpiration: Date?
}

// MARK: - JWT Token Helper

struct JWTHelper {
    static func decodeToken(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        let payload = segments[1]
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    static func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeToken(token),
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate < Date()
    }
    
    static func extractUserInfo(from token: String) -> UserInfo? {
        guard let payload = decodeToken(token) else { return nil }
        
        let userIdString = payload["nameid"] as? String ?? payload["sub"] as? String
        guard let userIdString = userIdString,
              let userId = UUID(uuidString: userIdString) else { return nil }
        
        let email = payload["email"] as? String ?? ""
        let firstName = payload["given_name"] as? String
        let lastName = payload["family_name"] as? String
        
        return UserInfo(
            userId: userId,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }
    
    // MARK: - JWT Token Debugging
    
    static func debugToken(_ token: String) {
        print("🔍 JWT Token Debug Information:")
        print("📝 Full Token: \(token.prefix(50))...[truncated]")
        
        guard let payload = decodeToken(token) else {
            print("❌ Failed to decode token payload")
            return
        }
        
        print("📋 Token Claims:")
        for (key, value) in payload.sorted(by: { $0.key < $1.key }) {
            print("   \(key): \(value)")
        }
        
        // Check specific claims for SignalR
        let iss = payload["iss"] as? String ?? "❌ MISSING"
        let aud = payload["aud"] as? String ?? "❌ MISSING"
        let exp = payload["exp"] as? TimeInterval
        
        print("\n🔐 SignalR-specific claims:")
        print("   iss (issuer): \(iss)")
        print("   aud (audience): \(aud)")
        
        if let exp = exp {
            let expirationDate = Date(timeIntervalSince1970: exp)
            let isExpired = expirationDate < Date()
            print("   exp (expiration): \(expirationDate) - \(isExpired ? "❌ EXPIRED" : "✅ VALID")")
        } else {
            print("   exp (expiration): ❌ MISSING")
        }
        
        // Validation for SignalR requirements
        print("\n✅ SignalR Validation:")
        if iss == "SST_AuthServer" {
            print("   ✅ Issuer is correct (SST_AuthServer)")
        } else {
            print("   ❌ Issuer should be 'SST_AuthServer', got: \(iss)")
        }
        
        if aud == "NOTHINGSOCIAL" {
            print("   ✅ Audience is correct (NOTHINGSOCIAL)")
        } else {
            print("   ❌ Audience should be 'NOTHINGSOCIAL', got: \(aud)")
        }
    }
}
