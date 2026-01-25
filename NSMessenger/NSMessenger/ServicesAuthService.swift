//
//  AuthService.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine
import Network

class AuthService: ObservableObject {
    @Published var authState = AuthenticationState(
        isAuthenticated: false,
        token: nil,
        user: nil,
        tokenExpiration: nil
    )
    
    private let keychainService = KeychainService.shared
    private let configManager = ConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    static let shared = AuthService()
    
    private init() {
        checkExistingAuthentication()
    }
    
    // MARK: - Authentication Methods
    
    func login(username: String, password: String) async throws -> Bool {
        let loginRequest = LoginRequest(
            companyId: configManager.environment.companyId,
            username: username,
            password: password
        )
        
        // Try the configured URL first
        var urlString = "\(configManager.environment.authServerUrl)/api/Auth/Login"
        print("🔗 Attempting to connect to: \(urlString)")
        
        // If we're trying to connect to a local IP, request permission first
        if LocalNetworkPermission.shared.isLocalIPAddress(urlString) {
            print("🔓 Requesting local network permission for IP connection...")
            await LocalNetworkPermission.shared.requestPermissionIfNeeded(for: "10.10.60.70")
        }
        
        do {
            return try await performLoginWithRetry(loginRequest: loginRequest, urlString: urlString)
        } catch AuthError.networkError(let message) where message.contains("hostname could not be found") {
            // DNS resolution failed, server uses host headers - connect to IP with proper Host header
            print("🔄 DNS resolution failed for domain, trying direct IP with host headers...")
            
            // Request local network permission for IP fallback
            print("🔓 Requesting local network permission for IP fallback...")
            await LocalNetworkPermission.shared.requestPermissionIfNeeded(for: "10.10.60.70")
            
            // Server uses host headers - connect to IP but send proper Host header
            let fallbackConfigs = [
                (url: "https://10.10.60.70/api/Auth/Login", hostHeader: "authqa.axminc.com"),
                (url: "http://10.10.60.70/api/Auth/Login", hostHeader: "authqa.axminc.com")
            ]
            
            for config in fallbackConfigs {
                print("🔗 Trying IP with host header: \(config.url) (Host: \(config.hostHeader))")
                
                // First, test basic connectivity to the server (only on first attempt)
                if config.url == fallbackConfigs.first?.url {
                    await testServerConnectivity(config.url)
                }
                
                do {
                    return try await performLoginWithHostHeader(loginRequest: loginRequest, urlString: config.url, hostHeader: config.hostHeader)
                } catch AuthError.serverError(404) {
                    print("🔴 404 on \(config.url) with host header, trying next...")
                    continue
                } catch AuthError.endpointNotFound(_) {
                    print("🔴 Endpoint not found for \(config.url) with host header, trying next...")
                    continue
                } catch AuthError.serverError(let statusCode) {
                    print("🔴 HTTP \(statusCode) on \(config.url) with host header - trying next...")
                    continue
                } catch {
                    // For other errors, log but don't continue trying  
                    print("🔴 Non-HTTP error on \(config.url) with host header: \(error)")
                    throw error
                }
            }
            
            // If all host header attempts failed
            throw AuthError.endpointNotFound("No valid endpoint found with host headers")
            
        } catch let error as URLError where error.code == .cannotFindHost {
            // Another way DNS failures can manifest - server uses host headers
            print("🔄 Cannot find host, trying direct IP with host headers...")
            
            // Request local network permission for IP fallback
            print("🔓 Requesting local network permission for IP fallback...")
            await LocalNetworkPermission.shared.requestPermissionIfNeeded(for: "10.10.60.70")
            
            // Server uses host headers - connect to IP but send proper Host header
            let fallbackConfigs = [
                (url: "https://10.10.60.70/api/Auth/Login", hostHeader: "authqa.axminc.com"),
                (url: "http://10.10.60.70/api/Auth/Login", hostHeader: "authqa.axminc.com")
            ]
            
            for config in fallbackConfigs {
                print("🔗 Trying IP with host header: \(config.url) (Host: \(config.hostHeader))")
                do {
                    return try await performLoginWithHostHeader(loginRequest: loginRequest, urlString: config.url, hostHeader: config.hostHeader)
                } catch AuthError.serverError(404) {
                    print("🔴 404 on \(config.url) with host header, trying next...")
                    continue
                } catch AuthError.endpointNotFound(_) {
                    print("🔴 Endpoint not found for \(config.url) with host header, trying next...")
                    continue
                } catch AuthError.serverError(let statusCode) {
                    print("🔴 HTTP \(statusCode) on \(config.url) with host header - trying next...")
                    continue
                } catch {
                    // For other errors, log but don't continue trying
                    print("🔴 Non-HTTP error on \(config.url) with host header: \(error)")
                    throw error
                }
            }
            
            // If all host header attempts failed
            throw AuthError.endpointNotFound("No valid endpoint found with host headers")
        } catch let error as URLError where error.code == .serverCertificateUntrusted {
            // SSL certificate error - try with the domain name instead
            print("🔄 SSL certificate mismatch, trying with proper domain name...")
            
            // If we were using IP, try domain name instead
            if urlString.contains("10.10.60.70") {
                urlString = "https://authqa.axminc.com/api/Auth/Login"
                print("🔗 SSL Fix: Attempting to connect to: \(urlString)")
                return try await performLoginWithRetry(loginRequest: loginRequest, urlString: urlString)
            } else {
                throw error
            }
        }
    }
    
    private func performLoginWithRetry(loginRequest: LoginRequest, urlString: String, maxRetries: Int = 2) async throws -> Bool {
        for attempt in 1...maxRetries {
            do {
                return try await performLogin(loginRequest: loginRequest, urlString: urlString)
            } catch AuthError.localNetworkPermissionNeeded {
                print("🔄 Attempt \(attempt): Local network permission needed, waiting for user response...")
                
                if attempt < maxRetries {
                    // Wait for the user to respond to the permission dialog
                    print("⏱️ Waiting 4 seconds for permission dialog response...")
                    try await Task.sleep(for: .seconds(4))
                    print("🔄 Retrying connection after permission delay...")
                } else {
                    // Final attempt failed
                    throw AuthError.localNetworkPermissionNeeded
                }
            } catch {
                // For other errors, don't retry
                throw error
            }
        }
        
        // This shouldn't be reached
        throw AuthError.networkError("Unexpected error during retry")
    }
    
    private func performLogin(loginRequest: LoginRequest, urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            throw AuthError.networkError("Invalid URL: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        // Debug logging
        print("📤 Sending POST request to: \(url.absoluteString)")
        print("📤 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📤 Request body: \(bodyString)")
        }
        
        // Create custom URLSession that accepts self-signed certificates
        let urlSession = createCustomURLSession()
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            print("📡 HTTP Response Status: \(httpResponse.statusCode)")
            print("📡 Response Headers: \(httpResponse.allHeaderFields)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Response Body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw AuthError.invalidCredentials
                } else if httpResponse.statusCode == 404 {
                    throw AuthError.endpointNotFound(urlString)
                }
                throw AuthError.serverError(httpResponse.statusCode)
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            
            if loginResponse.success, let token = loginResponse.token {
                // Validate token and extract user info
                guard !JWTHelper.isTokenExpired(token),
                      let userInfo = JWTHelper.extractUserInfo(from: token) else {
                    throw AuthError.invalidToken
                }
                
                // Save token to keychain
                guard keychainService.saveJWTToken(token) else {
                    throw AuthError.keychainError
                }
                
                // Update auth state
                await MainActor.run {
                    self.authState = AuthenticationState(
                        isAuthenticated: true,
                        token: token,
                        user: userInfo,
                        tokenExpiration: self.getTokenExpiration(token)
                    )
                }
                
                return true
            } else {
                let errorMessage = loginResponse.errorMessage ?? "Login failed"
                throw AuthError.loginFailed(errorMessage)
            }
        } catch {
            // Better error handling for network issues with detailed SSL diagnosis
            if error is AuthError {
                throw error
            } else if let urlError = error as? URLError {
                // Use the SSL helper to diagnose TLS errors
                SSLCertificateHelper.shared.diagnoseTLSError(urlError, for: urlString)
                
                switch urlError.code {
                case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid:
                    throw AuthError.networkError("A TLS error caused the secure connection to fail.")
                case .cannotFindHost:
                    print("🔴 Cannot find host: \(urlError.localizedDescription)")
                    throw AuthError.networkError("hostname could not be found")
                case .timedOut:
                    print("🔴 Request timed out: \(urlError.localizedDescription)")
                    throw AuthError.networkError("Connection timed out")
                case .notConnectedToInternet:
                    // Check if this is a local network permission issue
                    if urlError.localizedDescription.contains("offline") || 
                       urlError.localizedDescription.contains("Local network prohibited") ||
                       urlError.localizedDescription.contains("network is down") {
                        print("🔄 Detected local network permission issue, retrying after delay...")
                        throw AuthError.localNetworkPermissionNeeded
                    }
                    print("🔴 Network error details: \(urlError.localizedDescription)")
                    throw AuthError.networkError("Connection failed: \(urlError.localizedDescription)")
                case .secureConnectionFailed:
                    throw AuthError.networkError("A TLS error caused the secure connection to fail.")
                default:
                    print("🔴 Network error details: \(urlError.localizedDescription)")
                    throw AuthError.networkError("A TLS error caused the secure connection to fail.")
                }
            } else {
                print("🔴 Unknown error details: \(error)")
                throw AuthError.networkError("Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Perform login with a custom Host header - for use with IP addresses and virtual hosting
    private func performLoginWithHostHeader(loginRequest: LoginRequest, urlString: String, hostHeader: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            throw AuthError.networkError("Invalid URL: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(hostHeader, forHTTPHeaderField: "Host")  // Override Host header for virtual hosting
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        // Debug logging
        print("📤 Sending POST request to: \(url.absoluteString)")
        print("📤 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📤 Request body: \(bodyString)")
        }
        
        // Create custom URLSession that accepts self-signed certificates
        let urlSession = createCustomURLSession()
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            print("📡 HTTP Response Status: \(httpResponse.statusCode)")
            print("📡 Response Headers: \(httpResponse.allHeaderFields)")
            
            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Response Body: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw AuthError.invalidCredentials
                } else if httpResponse.statusCode == 404 {
                    throw AuthError.endpointNotFound(urlString)
                }
                throw AuthError.serverError(httpResponse.statusCode)
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            
            if loginResponse.success, let token = loginResponse.token {
                // Validate token and extract user info
                guard !JWTHelper.isTokenExpired(token),
                      let userInfo = JWTHelper.extractUserInfo(from: token) else {
                    throw AuthError.invalidToken
                }
                
                // Save token to keychain
                guard keychainService.saveJWTToken(token) else {
                    throw AuthError.keychainError
                }
                
                // Update auth state
                await MainActor.run {
                    self.authState = AuthenticationState(
                        isAuthenticated: true,
                        token: token,
                        user: userInfo,
                        tokenExpiration: self.getTokenExpiration(token)
                    )
                }
                
                return true
            } else {
                let errorMessage = loginResponse.errorMessage ?? "Login failed"
                throw AuthError.loginFailed(errorMessage)
            }
        } catch {
            // Better error handling for network issues
            if error is AuthError {
                throw error
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid:
                    print("🔴 SSL Certificate error: \(urlError.localizedDescription)")
                    throw AuthError.networkError("SSL Certificate error: \(urlError.localizedDescription)")
                case .cannotFindHost:
                    print("🔴 Cannot find host: \(urlError.localizedDescription)")
                    throw AuthError.networkError("hostname could not be found")
                case .timedOut:
                    print("🔴 Request timed out: \(urlError.localizedDescription)")
                    throw AuthError.networkError("Connection timed out")
                case .notConnectedToInternet:
                    // Check if this is a local network permission issue
                    if urlError.localizedDescription.contains("offline") || 
                       urlError.localizedDescription.contains("Local network prohibited") ||
                       urlError.localizedDescription.contains("network is down") {
                        print("🔄 Detected local network permission issue, retrying after delay...")
                        throw AuthError.localNetworkPermissionNeeded
                    }
                    print("🔴 Network error details: \(urlError.localizedDescription)")
                    throw AuthError.networkError("Connection failed: \(urlError.localizedDescription)")
                default:
                    print("🔴 Network error details: \(urlError.localizedDescription)")
                    throw AuthError.networkError("Connection failed: \(urlError.localizedDescription)")
                }
            } else {
                print("🔴 Unknown error details: \(error)")
                throw AuthError.networkError("Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    func logout() {
        Task { @MainActor in
            keychainService.clearAllData()
            
            authState = AuthenticationState(
                isAuthenticated: false,
                token: nil,
                user: nil,
                tokenExpiration: nil
            )
        }
    }
    
    func checkExistingAuthentication() {
        Task { @MainActor in
            guard let token = keychainService.getJWTToken(),
                  !JWTHelper.isTokenExpired(token),
                  let userInfo = JWTHelper.extractUserInfo(from: token) else {
                logout()
                return
            }
            
            authState = AuthenticationState(
                isAuthenticated: true,
                token: token,
                user: userInfo,
                tokenExpiration: getTokenExpiration(token)
            )
        }
    }
    
    // MARK: - Token Management
    
    private func createCustomURLSession() -> URLSession {
        let delegate = SSLPinningDelegate()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // Configure TLS settings for better compatibility with self-signed certificates
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    private func getTokenExpiration(_ token: String) -> Date? {
        guard let payload = JWTHelper.decodeToken(token),
              let exp = payload["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }
    
    func isTokenValid() -> Bool {
        guard let token = authState.token else { return false }
        return !JWTHelper.isTokenExpired(token)
    }
    
    func refreshTokenIfNeeded() async throws {
        // In a real app, you would implement token refresh here
        // For now, if token is expired, force re-login
        if !isTokenValid() {
            logout()
            throw AuthError.tokenExpired
        }
    }
    
    // MARK: - Debug Methods
    
    private func testServerConnectivity(_ urlString: String) async {
        // Extract base URL for connectivity test
        guard let url = URL(string: urlString),
              let baseURL = URL(string: "\(url.scheme!)://\(url.host!):\(url.port ?? (url.scheme == "https" ? 443 : 80))") else {
            return
        }
        
        print("🔍 Testing basic connectivity to: \(baseURL.absoluteString)")
        
        // Try a simple GET request to the root path
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        let urlSession = createCustomURLSession()
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Server is reachable - HTTP Status: \(httpResponse.statusCode)")
                print("🔍 Server headers: \(httpResponse.allHeaderFields)")
                
                // Try to discover common API paths
                await discoverAPIEndpoints(baseURL: baseURL, urlSession: urlSession)
            }
        } catch {
            print("⚠️ Server connectivity test failed: \(error)")
        }
    }
    
    private func discoverAPIEndpoints(baseURL: URL, urlSession: URLSession) async {
        print("🔍 Attempting to discover available API endpoints...")
        
        // Try common API discovery paths
        let discoveryPaths = ["/", "/api", "/Auth", "/api/Auth", "/swagger", "/health", "/login", "/authenticate", "/token"]
        
        for path in discoveryPaths {
            guard let testURL = URL(string: baseURL.absoluteString + path) else { continue }
            
            var request = URLRequest(url: testURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 3.0
            
            do {
                let (data, response) = try await urlSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("📋 GET \(path): HTTP \(httpResponse.statusCode)")
                    
                    // For successful responses, check if it contains useful info
                    if httpResponse.statusCode < 400, let responseString = String(data: data, encoding: .utf8) {
                        if responseString.contains("swagger") || responseString.contains("api") || responseString.contains("Auth") {
                            print("   💡 Potentially useful endpoint found at \(path)")
                        }
                    }
                }
            } catch {
                print("📋 GET \(path): Failed - \(error.localizedDescription)")
            }
        }
        
        // Also try some POST requests to common endpoints to see if they respond differently
        print("🔍 Testing POST requests to potential auth endpoints...")
        let authPaths = ["/api/Auth/Login", "/Auth/Login", "/login", "/authenticate", "/api/login", "/api/authenticate"]
        
        for path in authPaths {
            guard let testURL = URL(string: baseURL.absoluteString + path) else { continue }
            
            var request = URLRequest(url: testURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8) // Empty JSON body
            request.timeoutInterval = 3.0
            
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("📋 POST \(path): HTTP \(httpResponse.statusCode)")
                    
                    // Look for different status codes that might indicate the endpoint exists
                    switch httpResponse.statusCode {
                    case 200...299:
                        print("   ✅ SUCCESS: This endpoint might be working!")
                    case 400:
                        print("   🟡 BAD REQUEST: Endpoint exists but needs proper data")
                    case 401:
                        print("   🟡 UNAUTHORIZED: Auth endpoint exists!")
                    case 405:
                        print("   🟡 METHOD NOT ALLOWED: Endpoint exists but wrong method")
                    case 404:
                        print("   🔴 NOT FOUND: Endpoint doesn't exist")
                    default:
                        print("   ⚠️ Other status: Endpoint might exist")
                    }
                }
            } catch {
                print("📋 POST \(path): Failed - \(error.localizedDescription)")
            }
        }
        
        // Check if there's a different service running on common ports
        print("🔍 Checking for services on other common ports...")
        await checkOtherPorts(host: baseURL.host ?? "10.10.60.70")
    }
    
    private func checkOtherPorts(host: String) async {
        let commonPorts: [UInt16] = [80, 443, 8080, 8443, 3000, 5000, 8000, 9000]
        
        for port in commonPorts {
            if await testPortConnectivity(host: host, port: port) {
                print("📡 Port \(port) is open on \(host)")
                
                // Try a quick HTTP request to see what's running
                if let scheme = (port == 443 || port == 8443) ? "https" : "http",
                   let url = URL(string: "\(scheme)://\(host):\(port)") {
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.timeoutInterval = 2.0
                    
                    do {
                        let urlSession = createCustomURLSession()
                        let (_, response) = try await urlSession.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse {
                            print("   📄 HTTP \(httpResponse.statusCode) on port \(port)")
                            if let server = httpResponse.allHeaderFields["Server"] as? String {
                                print("   🖥️ Server: \(server)")
                            }
                        }
                    } catch {
                        print("   ⚠️ HTTP request failed on port \(port): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func testPortConnectivity(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port),
                using: .tcp
            )
            
            var hasResumed = false
            let queue = DispatchQueue(label: "port-test")
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed(_):
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 2 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func debugCurrentToken() {
        guard let token = authState.token else {
            print("❌ No token available to debug")
            return
        }
        
        JWTHelper.debugToken(token)
    }
    
    /// Comprehensive server analysis to find where the API actually is
    func exploreServer(host: String = "10.10.60.70") async {
        print("🕵️ Starting comprehensive server exploration for \(host)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Check all common ports
        await checkOtherPorts(host: host)
        
        // For each open port, do deeper inspection
        let commonPorts: [UInt16] = [80, 443, 8080, 8443, 3000, 5000, 8000, 9000]
        
        for port in commonPorts {
            if await testPortConnectivity(host: host, port: port) {
                print("\n🔍 Detailed analysis of \(host):\(port)")
                let scheme = (port == 443 || port == 8443) ? "https" : "http"
                
                if let baseURL = URL(string: "\(scheme)://\(host):\(port)") {
                    let urlSession = createCustomURLSession()
                    await discoverAPIEndpoints(baseURL: baseURL, urlSession: urlSession)
                }
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🕵️ Server exploration complete")
    }
    
    /// Test all configured environments to see which one works
    func testAllEnvironments() async {
        print("🧪 Testing all configured environments...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let testCredentials = LoginRequest(
            companyId: configManager.environment.companyId,
            username: "test@test.com", // Using dummy credentials just to test endpoint existence
            password: "test"
        )
        
        for environment in ConfigurationManager.Environment.allCases {
            print("\n🧪 Testing \(environment.rawValue)")
            print("📍 Auth URL: \(environment.authServerUrl)")
            print("📍 SignalR URL: \(environment.signalRHubUrl)")
            
            let urlString = "\(environment.authServerUrl)/api/Auth/Login"
            
            do {
                guard let url = URL(string: urlString) else {
                    print("❌ Invalid URL: \(urlString)")
                    continue
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // For IP-based environments, set proper host header
                if urlString.contains("10.10.60.70") {
                    if environment == .qaDirectIP {
                        request.setValue("authqa.axminc.com", forHTTPHeaderField: "Host")
                        print("🔧 Setting Host header: authqa.axminc.com")
                    } else if environment == .qaInsecure {
                        request.setValue("authqa.axminc.com", forHTTPHeaderField: "Host")
                        print("🔧 Setting Host header: authqa.axminc.com")
                    }
                }
                
                request.httpBody = try JSONEncoder().encode(testCredentials)
                request.timeoutInterval = 5.0
                
                let urlSession = createCustomURLSession()
                let (_, response) = try await urlSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        print("✅ SUCCESS: Environment \(environment.rawValue) is working!")
                    case 400...499:
                        if httpResponse.statusCode == 401 {
                            print("🟢 ENDPOINT EXISTS: Environment \(environment.rawValue) - Auth endpoint found (401 Unauthorized)")
                        } else if httpResponse.statusCode == 400 {
                            print("🟡 ENDPOINT EXISTS: Environment \(environment.rawValue) - Bad request (endpoint exists)")
                        } else if httpResponse.statusCode == 404 {
                            print("🔴 NOT FOUND: Environment \(environment.rawValue) - Endpoint doesn't exist")
                        } else {
                            print("🟠 PARTIAL: Environment \(environment.rawValue) - HTTP \(httpResponse.statusCode)")
                        }
                    case 500...599:
                        print("🔴 SERVER ERROR: Environment \(environment.rawValue) - HTTP \(httpResponse.statusCode)")
                    default:
                        print("⚠️ UNKNOWN: Environment \(environment.rawValue) - HTTP \(httpResponse.statusCode)")
                    }
                    
                    // Show server information
                    if let server = httpResponse.allHeaderFields["Server"] as? String {
                        print("   🖥️ Server: \(server)")
                    }
                }
            } catch {
                print("🔴 FAILED: Environment \(environment.rawValue) - \(error.localizedDescription)")
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 Environment testing complete")
        print("💡 Try switching to 'QA (Direct IP with Host Headers)' or 'QA (HTTP - Host Headers)' environment")
    }
    
    /// Comprehensive SSL debugging and testing method
    func diagnoseSSLIssues() async {
        print("🩺 Starting SSL diagnosis for authqa.axminc.com...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        let testURLs = [
            "https://authqa.axminc.com/api/Auth/Login",
            "https://10.10.60.70/api/Auth/Login",
            "http://10.10.60.70/api/Auth/Login"
        ]
        
        for urlString in testURLs {
            await testSSLConnection(urlString)
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🩺 SSL diagnosis complete")
        print("💡 If all tests fail with TLS errors, check your Info.plist ATS configuration")
        print("💡 Consider adding the domains to NSExceptionDomains in your Info.plist")
    }
    
    private func testSSLConnection(_ urlString: String) async {
        print("\n🧪 Testing SSL connection to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Simple GET request for testing
        request.timeoutInterval = 10.0
        
        // If this is an IP connection, add host header
        if urlString.contains("10.10.60.70") {
            request.setValue("authqa.axminc.com", forHTTPHeaderField: "Host")
            print("🔧 Added Host header: authqa.axminc.com")
        }
        
        let urlSession = createCustomURLSession()
        
        do {
            print("⏳ Attempting connection...")
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Connection successful!")
                print("   📊 HTTP Status: \(httpResponse.statusCode)")
                print("   📋 Headers: \(httpResponse.allHeaderFields)")
                
                if let responseString = String(data: data, encoding: .utf8), responseString.count < 1000 {
                    print("   📄 Response preview: \(responseString.prefix(200))")
                }
            }
            
        } catch let error as URLError {
            print("❌ Connection failed with URLError:")
            print("   🔢 Code: \(error.code.rawValue) (\(error.code))")
            print("   📝 Description: \(error.localizedDescription)")
            
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   🔍 Underlying error: \(underlyingError.domain) \(underlyingError.code)")
                print("   📋 Underlying info: \(underlyingError.userInfo)")
            }
            
            // Specific analysis for TLS errors
            if error.code == .serverCertificateUntrusted {
                print("   💡 This is a certificate trust issue")
                print("   🔧 Your SSL delegate should handle this")
            } else if error.code.rawValue == -1200 {
                print("   💡 This is error -1200 (SSL connection failure)")
                print("   🔧 Check ATS configuration in Info.plist")
                print("   🔧 Verify SSL certificate delegate is working")
            }
            
        } catch {
            print("❌ Connection failed with other error: \(error)")
        }
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case networkError(String)
    case serverError(Int)
    case invalidCredentials
    case loginFailed(String)
    case invalidToken
    case tokenExpired
    case keychainError
    case localNetworkPermissionNeeded
    case endpointNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please check the server status."
        case .invalidCredentials:
            return "Invalid Password"
        case .loginFailed(let message):
            return message
        case .invalidToken:
            return "Invalid authentication token"
        case .tokenExpired:
            return "Session expired. Please log in again."
        case .keychainError:
            return "Failed to save authentication data"
        case .localNetworkPermissionNeeded:
            return "Please allow local network access and try again"
        case .endpointNotFound(let endpoint):
            return "API endpoint not found: \(endpoint). Please check server configuration."
        }
    }
}

// MARK: - SSL Certificate Handling

class SSLPinningDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        print("🔐 SSL Challenge received for: \(challenge.protectionSpace.host)")
        print("🔐 Authentication method: \(challenge.protectionSpace.authenticationMethod)")
        
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            print("🔐 Not a server trust challenge, using default handling")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get the server trust
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            print("🔴 No server trust available")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Accept certificates for our trusted internal servers
        // The server at 10.10.60.70 has a certificate for *.axminc.com
        if host == "10.10.60.70" || host.hasSuffix(".axminc.com") || host == "authqa.axminc.com" {
            print("🔓 Accepting certificate for trusted host: \(host)")
            
            // Use the detailed certificate helper for analysis
            SSLCertificateHelper.shared.analyzeServerTrust(serverTrust, for: host)
            
            // Create a lenient credential using our helper
            if let credential = SSLCertificateHelper.shared.createLenientServerTrust(for: serverTrust, hostname: host) {
                print("✅ Certificate credential created successfully")
                completionHandler(.useCredential, credential)
                return
            }
            
            // Fallback: Accept the certificate regardless of validation issues
            print("🔧 Using fallback credential creation")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            
        } else {
            print("⚠️ Untrusted host: \(host), using default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle task-level authentication challenges (this can catch some cases that session-level doesn't)
        print("🔐 Task-level SSL Challenge received for: \(challenge.protectionSpace.host)")
        
        // Delegate to the session-level handler
        self.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
}
