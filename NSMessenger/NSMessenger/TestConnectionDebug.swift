//
//  TestConnectionDebug.swift
//  NSMessenger
//
//  Created by Assistant on 1/25/26.
//

import Foundation

// Quick test to see if we can reach the SignalR endpoint
func testSignalREndpoint() async {
    print("🌐 Testing SignalR endpoint connectivity...")
    
    let url = URL(string: "https://nsmessageserviceqa.axminc.com/messageHub/negotiate?negotiateVersion=1")!
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ HTTP Response Status: \(httpResponse.statusCode)")
            print("📊 Response Headers: \(httpResponse.allHeaderFields)")
            print("📊 Response Data Size: \(data.count) bytes")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response Body: \(responseString)")
            }
        }
    } catch {
        print("❌ Failed to connect to SignalR endpoint: \(error)")
    }
}

// Test with authentication token
func testSignalREndpointWithAuth() async {
    print("🔐 Testing SignalR endpoint with authentication...")
    
    let url = URL(string: "https://nsmessageserviceqa.axminc.com/messageHub/negotiate?negotiateVersion=1")!
    var request = URLRequest(url: url)
    
    // Get the current auth token
    let authService = AuthService.shared
    if let token = authService.authState.accessToken {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("🔐 Added Bearer token to request")
    }
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ Authenticated HTTP Response Status: \(httpResponse.statusCode)")
            print("📊 Response Headers: \(httpResponse.allHeaderFields)")
            print("📊 Response Data Size: \(data.count) bytes")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Authenticated Response Body: \(responseString)")
            }
        }
    } catch {
        print("❌ Failed to connect to SignalR endpoint with auth: \(error)")
    }
}