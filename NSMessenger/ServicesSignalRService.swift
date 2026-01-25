//
//  SignalRService.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation
import Combine

// MARK: - Helper Extensions

extension DateFormatter {
    func apply(closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// MARK: - SignalR Protocol Models

struct SignalRInvocationMessage: Codable {
    let type: Int = 1 // Invocation message type
    let invocationId: String
    let target: String
    let arguments: [AnyCodable]
    
    init(invocationId: String, target: String, arguments: [Any]) {
        self.invocationId = invocationId
        self.target = target
        self.arguments = arguments.map { AnyCodable($0) }
    }
}

struct SignalRResponseMessage: Codable {
    let type: Int
    let invocationId: String?
    let result: AnyCodable?
    let error: String?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            // Try to decode as NSNull for explicit null values
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let decimal as Decimal:
            try container.encode(decimal)
        case let string as String:
            try container.encode(string)
        case let uuid as UUID:
            try container.encode(uuid.uuidString)
        case let url as URL:
            try container.encode(url.absoluteString)
        case let date as Date:
            try container.encode(date.timeIntervalSince1970)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let dict as [AnyHashable: Any]:
            // Convert AnyHashable keys to String
            let stringDict = dict.reduce(into: [String: Any]()) { result, element in
                result[String(describing: element.key)] = element.value
            }
            try container.encode(stringDict.mapValues { AnyCodable($0) })
        default:
            // Fallback: try to encode as string representation
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - SignalR Service Protocol

protocol SignalRServiceProtocol {
    func connect() async throws
    func disconnect()
    func invoke<T: Codable>(_ method: String, parameters: [Any]) async throws -> T?
    func on<T: Codable>(_ method: String, callback: @escaping (T) -> Void)
    var connectionState: SignalRConnectionState { get }
    var connectionStatePublisher: AnyPublisher<SignalRConnectionState, Never> { get }
}

// MARK: - Connection States

enum SignalRConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
    
    static func == (lhs: SignalRConnectionState, rhs: SignalRConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.reconnecting, .reconnecting):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - SignalR Service Implementation
// This implementation uses HTTP-based SignalR communication with URLSession

class SignalRService: SignalRServiceProtocol, ObservableObject {
    @Published var connectionState: SignalRConnectionState = .disconnected
    
    var isConnected: Bool {
        return connectionState == .connected
    }
    
    var connectionStatePublisher: AnyPublisher<SignalRConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }
    
    private let configManager = ConfigurationManager.shared
    private let authService = AuthService.shared
    private var eventHandlers: [String: (Any) -> Void] = [:]
    private var urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    
    // SignalR invocation tracking
    private var pendingInvocations: [String: (Result<Any?, Error>) -> Void] = [:]
    private var invocationCounter: Int = 0
    private let invocationQueue = DispatchQueue(label: "signalr.invocations", attributes: .concurrent)
    
    static let shared = SignalRService()
    
    private init() {
        // Create URLSession with proper configuration and SSL certificate handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        // Use custom delegate for SSL certificate handling
        self.urlSession = URLSession(configuration: config, delegate: SignalRSSLDelegate(), delegateQueue: nil)
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let token = authService.authState.token else {
            throw SignalRError.noAuthToken
        }
        
        // Debug the JWT token
        print("🔍 Debugging JWT Token for SignalR:")
        JWTHelper.debugToken(token)
        
        await MainActor.run {
            self.connectionState = .connecting
        }
        
        let hubUrl = configManager.environment.signalRHubUrl
        print("🔗 Connecting to SignalR Hub: \(hubUrl)")
        
        // Check if we need local network permission for IP-based connections
        if hubUrl.contains("10.10.60.70") {
            print("🔓 Requesting local network permission for SignalR...")
            await LocalNetworkPermission.shared.requestPermissionIfNeeded(for: "10.10.60.70")
        }
        
        do {
            // Step 1: Perform SignalR negotiation
            try await performNegotiation(token: token)
            
            // Step 2: Set up WebSocket connection
            try await setupWebSocketConnection(token: token)
            
            await MainActor.run {
                self.connectionState = .connected
            }
            print("✅ SignalR connected successfully")
            
        } catch let error as SignalRError {
            if case .connectionFailed(let message) = error, message.contains("hostname could not be found") {
                // DNS resolution failed, try IP fallback with host headers
                print("🔄 DNS resolution failed for SignalR, trying direct IP with host headers...")
                try await connectWithIPFallback(token: token, originalError: message)
            } else {
                await MainActor.run {
                    self.connectionState = .failed(error)
                }
                throw error
            }
        } catch {
            // Check if this is a hostname resolution error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("hostname could not be found") || errorString.contains("could not be found") {
                print("🔄 DNS resolution failed for SignalR, trying direct IP with host headers...")
                try await connectWithIPFallback(token: token, originalError: error.localizedDescription)
            } else {
                await MainActor.run {
                    self.connectionState = .failed(error)
                }
                throw SignalRError.connectionFailed(error.localizedDescription)
            }
        }
    }
    
    private func performNegotiation(token: String) async throws {
        let hubUrl = configManager.environment.signalRHubUrl
        
        // For SignalR, the negotiate endpoint can be in different locations depending on the server setup:
        // Option 1: https://example.com/messageHub/negotiate (same path as hub + /negotiate)
        // Option 2: https://example.com/negotiate (base URL + /negotiate)
        
        guard var urlComponents = URLComponents(string: hubUrl) else {
            throw SignalRError.connectionFailed("Invalid hub URL: \(hubUrl)")
        }
        
        // Try the hub-specific negotiate endpoint first (most common for ASP.NET Core SignalR)
        urlComponents.path = urlComponents.path + "/negotiate"
        urlComponents.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]
        
        guard let primaryNegotiateUrl = urlComponents.url else {
            throw SignalRError.connectionFailed("Failed to create negotiate URL")
        }
        
        print("🤝 Performing SignalR negotiation: \(primaryNegotiateUrl)")
        
        var request = URLRequest(url: primaryNegotiateUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if 200...299 ~= httpResponse.statusCode {
                    // Parse negotiation response
                    if let negotiationResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ SignalR negotiation successful: \(negotiationResponse)")
                    } else {
                        print("✅ SignalR negotiation successful (no response data)")
                    }
                    return
                } else if httpResponse.statusCode == 404 {
                    print("⚠️ Hub-specific negotiate endpoint returned 404, trying fallback...")
                    // Try the fallback approach
                    try await performFallbackNegotiation(token: token, originalHubUrl: hubUrl)
                    return
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw SignalRError.connectionFailed("Negotiation failed: HTTP \(httpResponse.statusCode) - \(errorMessage)")
                }
            } else {
                throw SignalRError.connectionFailed("Invalid negotiation response")
            }
        } catch let error as SignalRError {
            throw error
        } catch {
            print("⚠️ Primary negotiation failed with error: \(error), trying fallback...")
            try await performFallbackNegotiation(token: token, originalHubUrl: hubUrl)
        }
    }
    
    private func performFallbackNegotiation(token: String, originalHubUrl: String) async throws {
        // Fallback: try negotiate at the base URL
        guard let baseUrl = URL(string: originalHubUrl)?.deletingLastPathComponent() else {
            throw SignalRError.connectionFailed("Invalid hub URL for fallback: \(originalHubUrl)")
        }
        
        var urlComponents = URLComponents(url: baseUrl.appendingPathComponent("negotiate"), resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]
        
        guard let fallbackNegotiateUrl = urlComponents?.url else {
            throw SignalRError.connectionFailed("Failed to create fallback negotiate URL")
        }
        
        print("🤝 Performing fallback SignalR negotiation: \(fallbackNegotiateUrl)")
        
        var request = URLRequest(url: fallbackNegotiateUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if 200...299 ~= httpResponse.statusCode {
                // Parse negotiation response
                if let negotiationResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Fallback SignalR negotiation successful: \(negotiationResponse)")
                } else {
                    print("✅ Fallback SignalR negotiation successful (no response data)")
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SignalRError.connectionFailed("Fallback negotiation also failed: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            }
        } else {
            throw SignalRError.connectionFailed("Invalid fallback negotiation response")
        }
    }
    
    /// IP fallback connection for when DNS resolution fails - similar to auth service approach
    private func connectWithIPFallback(token: String, originalError: String) async throws {
        print("🔓 Requesting local network permission for SignalR IP fallback...")
        await LocalNetworkPermission.shared.requestPermissionIfNeeded(for: "10.10.60.70")
        
        // Server uses host headers - connect to IP but send proper Host header
        let fallbackConfigs = [
            (hubUrl: "https://10.10.60.70/messageHub", hostHeader: "nsmessageserviceqa.axminc.com"),
            (hubUrl: "http://10.10.60.70/messageHub", hostHeader: "nsmessageserviceqa.axminc.com")
        ]
        
        for config in fallbackConfigs {
            print("🔗 Trying SignalR IP with host header: \(config.hubUrl) (Host: \(config.hostHeader))")
            
            do {
                try await performNegotiationWithHostHeader(token: token, hubUrl: config.hubUrl, hostHeader: config.hostHeader)
                try await setupWebSocketConnectionWithHostHeader(token: token, hubUrl: config.hubUrl, hostHeader: config.hostHeader)
                
                await MainActor.run {
                    self.connectionState = .connected
                }
                print("✅ SignalR connected successfully via IP with host headers")
                return
                
            } catch SignalRError.connectionFailed(let message) where message.contains("404") {
                print("🔴 404 on \(config.hubUrl) with host header, trying next...")
                continue
            } catch {
                print("🔴 Failed to connect to \(config.hubUrl) with host header: \(error)")
                continue
            }
        }
        
        // If all fallback attempts failed, throw the original error
        await MainActor.run {
            self.connectionState = .failed(SignalRError.connectionFailed(originalError))
        }
        throw SignalRError.connectionFailed("All SignalR connection attempts failed. Original error: \(originalError)")
    }
    
    /// Perform negotiation with custom host header for IP connections
    private func performNegotiationWithHostHeader(token: String, hubUrl: String, hostHeader: String) async throws {
        guard var urlComponents = URLComponents(string: hubUrl) else {
            throw SignalRError.connectionFailed("Invalid hub URL: \(hubUrl)")
        }
        
        // Try the hub-specific negotiate endpoint first
        urlComponents.path = urlComponents.path + "/negotiate"
        urlComponents.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]
        
        guard let primaryNegotiateUrl = urlComponents.url else {
            throw SignalRError.connectionFailed("Failed to create negotiate URL")
        }
        
        print("🤝 Performing SignalR negotiation with host header: \(primaryNegotiateUrl)")
        
        var request = URLRequest(url: primaryNegotiateUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(hostHeader, forHTTPHeaderField: "Host")
        request.timeoutInterval = 10
        
        let (data, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if 200...299 ~= httpResponse.statusCode {
                if let negotiationResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ SignalR negotiation successful with host header: \(negotiationResponse)")
                } else {
                    print("✅ SignalR negotiation successful with host header (no response data)")
                }
                return
            } else if httpResponse.statusCode == 404 {
                // Try fallback negotiate endpoint
                guard let baseUrl = URL(string: hubUrl)?.deletingLastPathComponent() else {
                    throw SignalRError.connectionFailed("Invalid hub URL for fallback: \(hubUrl)")
                }
                
                var fallbackComponents = URLComponents(url: baseUrl.appendingPathComponent("negotiate"), resolvingAgainstBaseURL: false)
                fallbackComponents?.queryItems = [URLQueryItem(name: "negotiateVersion", value: "1")]
                
                guard let fallbackUrl = fallbackComponents?.url else {
                    throw SignalRError.connectionFailed("Failed to create fallback negotiate URL")
                }
                
                var fallbackRequest = URLRequest(url: fallbackUrl)
                fallbackRequest.httpMethod = "POST"
                fallbackRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                fallbackRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                fallbackRequest.setValue(hostHeader, forHTTPHeaderField: "Host")
                fallbackRequest.timeoutInterval = 10
                
                let (fallbackData, fallbackResponse) = try await urlSession.data(for: fallbackRequest)
                
                if let fallbackHttpResponse = fallbackResponse as? HTTPURLResponse {
                    if 200...299 ~= fallbackHttpResponse.statusCode {
                        print("✅ SignalR fallback negotiation successful with host header")
                        return
                    } else {
                        let errorMessage = String(data: fallbackData, encoding: .utf8) ?? "Unknown error"
                        throw SignalRError.connectionFailed("Negotiation failed: HTTP \(fallbackHttpResponse.statusCode) - \(errorMessage)")
                    }
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SignalRError.connectionFailed("Negotiation failed: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            }
        } else {
            throw SignalRError.connectionFailed("Invalid negotiation response")
        }
    }
    
    /// Setup WebSocket connection with custom host header for IP connections
    private func setupWebSocketConnectionWithHostHeader(token: String, hubUrl: String, hostHeader: String) async throws {
        print("🔍 Setting up WebSocket with host header - Hub URL: \(hubUrl)")
        
        guard var urlComponents = URLComponents(string: hubUrl) else {
            throw SignalRError.connectionFailed("Invalid hub URL: \(hubUrl)")
        }
        
        // Add the access token as a query parameter (required for SignalR WebSocket auth)
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "access_token", value: token))
        urlComponents.queryItems = queryItems
        
        // Convert HTTP(S) to WebSocket scheme
        let originalScheme = urlComponents.scheme
        if urlComponents.scheme == "https" {
            urlComponents.scheme = "wss"
        } else if urlComponents.scheme == "http" {
            urlComponents.scheme = "ws"
        } else {
            print("⚠️ Unexpected URL scheme: \(originalScheme ?? "nil")")
        }
        
        guard let wsUrl = urlComponents.url else {
            throw SignalRError.connectionFailed("Failed to create WebSocket URL")
        }
        
        print("🔌 WebSocket URL with host header: \(wsUrl.absoluteString.replacingOccurrences(of: token, with: "[TOKEN]"))")
        
        var request = URLRequest(url: wsUrl)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(hostHeader, forHTTPHeaderField: "Host")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        
        // Start listening for messages BEFORE we resume the task
        listenForWebSocketMessages()
        
        // Resume the WebSocket task
        webSocketTask?.resume()
        print("🔌 WebSocket task with host header resumed, waiting for connection...")
        
        // Wait a brief moment for the connection to establish
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Send SignalR handshake message after connection is established
        try await sendHandshakeMessage()
        
        print("🔌 WebSocket connection with host header established for real-time events")
    }
    
    private func setupWebSocketConnection(token: String) async throws {
        let hubUrl = configManager.environment.signalRHubUrl
        print("🔍 Original hub URL: \(hubUrl)")
        
        // Create URL components to properly add the access token query parameter
        guard var urlComponents = URLComponents(string: hubUrl) else {
            throw SignalRError.connectionFailed("Invalid hub URL: \(hubUrl)")
        }
        
        // Add the access token as a query parameter (required for SignalR WebSocket auth)
        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "access_token", value: token))
        urlComponents.queryItems = queryItems
        
        // Convert to WebSocket URL
        let originalScheme = urlComponents.scheme
        if urlComponents.scheme == "https" {
            urlComponents.scheme = "wss"
        } else if urlComponents.scheme == "http" {
            urlComponents.scheme = "ws"
        } else {
            print("⚠️ Unexpected URL scheme: \(originalScheme ?? "nil")")
        }
        
        guard let wsUrl = urlComponents.url else {
            throw SignalRError.connectionFailed("Failed to create WebSocket URL")
        }
        
        print("🔌 WebSocket URL: \(wsUrl.absoluteString.replacingOccurrences(of: token, with: "[TOKEN]"))")
        
        var request = URLRequest(url: wsUrl)
        // Add some additional headers that might help with SignalR compatibility
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        
        // Start listening for messages BEFORE we resume the task
        listenForWebSocketMessages()
        
        // Resume the WebSocket task
        webSocketTask?.resume()
        print("🔌 WebSocket task resumed, waiting for connection...")
        
        // Wait a brief moment for the connection to establish
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Send SignalR handshake message after connection is established
        try await sendHandshakeMessage()
        
        print("🔌 WebSocket connection established for real-time events")
    }
    
    private func sendHandshakeMessage() async throws {
        // SignalR handshake protocol requires sending this specific message
        // The \u{1E} is the record separator character (ASCII 30)
        let handshakeMessage = "{\"protocol\":\"json\",\"version\":1}\u{1E}"
        
        guard let webSocketTask = webSocketTask else {
            throw SignalRError.connectionFailed("WebSocket task not available")
        }
        
        print("🤝 Sending SignalR handshake message")
        
        return try await withCheckedThrowingContinuation { continuation in
            let message = URLSessionWebSocketTask.Message.string(handshakeMessage)
            webSocketTask.send(message) { error in
                if let error = error {
                    print("❌ Failed to send handshake: \(error)")
                    continuation.resume(throwing: SignalRError.connectionFailed("Handshake failed: \(error.localizedDescription)"))
                } else {
                    print("✅ SignalR handshake message sent successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    private func listenForWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleWebSocketMessage(text)
                    } else {
                        print("⚠️ Received binary data that could not be converted to string")
                    }
                @unknown default:
                    print("⚠️ Received unknown WebSocket message type")
                    break
                }
                // Continue listening
                self?.listenForWebSocketMessages()
                
            case .failure(let error):
                print("❌ WebSocket error: \(error)")
                
                // Check for specific WebSocket close codes
                if let wsError = error as? URLError {
                    switch wsError.code {
                    case .cancelled:
                        print("🔌 WebSocket connection was cancelled")
                    case .networkConnectionLost:
                        print("🔌 WebSocket network connection lost - attempting reconnection")
                        Task { @MainActor in
                            self?.connectionState = .reconnecting
                        }
                        // Attempt reconnection with exponential backoff
                        Task {
                            await self?.attemptReconnection()
                        }
                        return
                    default:
                        print("🔌 WebSocket URLError: \(wsError.localizedDescription)")
                    }
                }
                
                Task { @MainActor in
                    self?.connectionState = .failed(error)
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: String) {
        print("📨 WebSocket message received: \(message)")
        
        // Split message by SignalR delimiter if needed
        let messages = message.components(separatedBy: "\u{1E}").filter { !$0.isEmpty }
        
        for msgText in messages {
            // Handle empty handshake response (SignalR sends empty message after successful handshake)
            if msgText.isEmpty || msgText == "{}" {
                print("✅ SignalR handshake completed successfully")
                continue
            }
            
            // Try to parse as JSON first
            guard let data = msgText.data(using: .utf8) else {
                print("⚠️ Could not convert message to data: \(msgText)")
                continue
            }
            
            // Check if this is a handshake error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? String, json["type"] == nil {
                    print("❌ SignalR handshake error: \(error)")
                    Task { @MainActor in
                        self.connectionState = .failed(SignalRError.connectionFailed("Handshake error: \(error)"))
                    }
                    continue
                }
                
                // Check message type
                if let messageType = json["type"] as? Int {
                    switch messageType {
                    case 1: // Invocation - can be server-to-client (events) or client-to-server
                        // Check if this is a server-to-client invocation (has target)
                        if json["target"] is String {
                            print("📢 Received server-to-client invocation (event)")
                            handleEvent(json)
                        } else {
                            print("⚠️ Received unexpected client-to-server invocation")
                        }
                        
                    case 3: // InvocationResponse
                        handleInvocationResponse(json)
                        
                    case 6: // Ping message
                        print("📡 Received ping/keep-alive message")
                        // Ping messages don't need handling, they're just keep-alive
                        
                    case 7: // Close message
                        print("🔌 Received close message")
                        
                    default: // Unknown message types
                        print("❓ Received unknown message type: \(messageType)")
                        // Only try to handle as event if it has a target
                        if json["target"] is String {
                            handleEvent(json)
                        }
                    }
                } else {
                    // Legacy format - treat as event
                    handleEvent(json)
                }
            } else {
                // If it's not valid JSON, it might be a handshake response or error
                print("⚠️ Could not parse message as JSON: \(msgText)")
                
                // Check if this looks like a handshake error
                if msgText.contains("error") && msgText.contains("handshake") {
                    print("❌ SignalR handshake error in non-JSON format: \(msgText)")
                    Task { @MainActor in
                        self.connectionState = .failed(SignalRError.connectionFailed("Handshake error: \(msgText)"))
                    }
                }
            }
        }
    }
    
    private func handleInvocationResponse(_ json: [String: Any]) {
        guard let invocationId = json["invocationId"] as? String else {
            print("⚠️ Invocation response missing invocationId")
            return
        }
        
        print("📥 SignalR Response: \(invocationId)")
        
        invocationQueue.async(flags: .barrier) {
            guard let resultHandler = self.pendingInvocations.removeValue(forKey: invocationId) else {
                print("⚠️ No pending invocation found for \(invocationId)")
                return
            }
            
            if let error = json["error"] as? String {
                print("❌ SignalR Error for \(invocationId): \(error)")
                resultHandler(.failure(SignalRError.invocationFailed(error)))
            } else if let result = json["result"] {
                print("✅ SignalR Success for \(invocationId)")
                resultHandler(.success(result))
            } else {
                // No result (void method)
                resultHandler(.success(nil))
            }
        }
    }
    
    private func handleEvent(_ json: [String: Any]) {
        guard let target = json["target"] as? String else {
            print("❌ Event missing target")
            return
        }
        
        print("📢 SignalR Event: \(target)")
        
        // Get the arguments array and extract the first argument
        if let arguments = json["arguments"] as? [Any], let firstArg = arguments.first {
            print("📝 Event argument type: \(type(of: firstArg))")
            print("📝 Event argument content: \(firstArg)")
            
            // Trigger registered event handlers
            if let handler = eventHandlers[target] {
                handler(firstArg)
            } else {
                print("⚠️ No handler registered for event: \(target)")
            }
        } else {
            print("❌ Event missing arguments or first argument")
        }
    }
    
    func disconnect() {
        Task {
            webSocketTask?.cancel()
            webSocketTask = nil
            
            await MainActor.run {
                self.connectionState = .disconnected
            }
            eventHandlers.removeAll()
            print("🔗 SignalR Service disconnected")
        }
    }
    
    // MARK: - Reconnection Logic
    
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 5
    
    private func attemptReconnection() async {
        guard reconnectionAttempts < maxReconnectionAttempts else {
            print("❌ Maximum reconnection attempts reached")
            await MainActor.run {
                self.connectionState = .failed(SignalRError.connectionFailed("Max reconnection attempts reached"))
            }
            return
        }
        
        reconnectionAttempts += 1
        let delay = min(pow(2.0, Double(reconnectionAttempts)), 30.0) // Exponential backoff with max 30s
        
        print("🔄 Reconnection attempt \(reconnectionAttempts)/\(maxReconnectionAttempts) in \(delay)s")
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            try await connect()
            reconnectionAttempts = 0 // Reset on successful connection
            print("✅ Reconnected successfully")
            
            // Notify MessagingService to re-register event handlers
            NotificationCenter.default.post(name: .signalRReconnected, object: nil)
        } catch {
            print("❌ Reconnection attempt \(reconnectionAttempts) failed: \(error)")
            await attemptReconnection()
        }
    }
    
    // MARK: - Hub Method Invocation
    
    func invoke<T: Codable>(_ method: String, parameters: [Any]) async throws -> T? {
        guard isConnected, let webSocketTask = webSocketTask else {
            throw SignalRError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T?, Error>) in
            invocationQueue.async(flags: .barrier) {
                self.invocationCounter += 1
                let invocationId = "inv_\(self.invocationCounter)"
                
                // Store a closure that will handle the result and resume the continuation
                self.pendingInvocations[invocationId] = { result in
                    switch result {
                    case .success(let value):
                        if let typedValue = value as? T {
                            continuation.resume(returning: typedValue)
                        } else if value == nil || (value is NSNull) {
                            // Handle null/void returns
                            continuation.resume(returning: nil)
                        } else {
                            // Try to convert to JSON and decode
                            do {
                                let jsonData: Data
                                
                                // Handle different value types for JSON serialization
                                if let dictValue = value as? [String: Any] {
                                    jsonData = try JSONSerialization.data(withJSONObject: dictValue, options: [])
                                } else if let arrayValue = value as? [Any] {
                                    jsonData = try JSONSerialization.data(withJSONObject: arrayValue, options: [])
                                } else if let stringValue = value as? String {
                                    jsonData = stringValue.data(using: .utf8) ?? Data()
                                } else {
                                    // For any other type, try to encode it using JSONEncoder first
                                    do {
                                        // Try encoding with custom AnyCodable wrapper
                                        let wrapper = AnyCodable(value)
                                        jsonData = try JSONEncoder().encode(wrapper)
                                    } catch {
                                        // If that fails, try direct JSON serialization
                                        do {
                                            jsonData = try JSONSerialization.data(withJSONObject: value, options: [])
                                        } catch {
                                            // Last resort: convert to string
                                            let stringRepresentation = String(describing: value)
                                            jsonData = stringRepresentation.data(using: .utf8) ?? Data()
                                        }
                                    }
                                }
                                
                                let decodedValue = try JSONDecoder().decode(T.self, from: jsonData)
                                continuation.resume(returning: decodedValue)
                            } catch {
                                print("❌ JSON conversion error for \(invocationId): \(error)")
                                print("❌ Value type: \(type(of: value))")
                                print("❌ Value: \(value)")
                                
                                // If we're expecting an optional type and got null/void, return nil
                                if "\(T.self)".contains("Optional") {
                                    continuation.resume(returning: nil)
                                } else {
                                    continuation.resume(throwing: SignalRError.invocationFailed("Type conversion failed: \(error.localizedDescription)"))
                                }
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }               
                // Create SignalR invocation message
                let invocation = SignalRInvocationMessage(
                    invocationId: invocationId,
                    target: method,
                    arguments: parameters
                )
                
                do {
                    // Encode message to JSON
                    let encoder = JSONEncoder()
                    let messageData = try encoder.encode(invocation)
                    let messageString = String(data: messageData, encoding: .utf8)! + "\u{1E}" // SignalR message delimiter
                    
                    print("📤 SignalR Invoke: \(method) - \(invocationId)")
                    
                    // Send the message via WebSocket
                    let webSocketMessage = URLSessionWebSocketTask.Message.string(messageString)
                    webSocketTask.send(webSocketMessage) { error in
                        if let error = error {
                            self.invocationQueue.async(flags: .barrier) {
                                if let resultHandler = self.pendingInvocations.removeValue(forKey: invocationId) {
                                    resultHandler(.failure(SignalRError.invocationFailed(error.localizedDescription)))
                                }
                            }
                        }
                    }
                    
                    // Set up timeout
                    DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                        self.invocationQueue.async(flags: .barrier) {
                            if let resultHandler = self.pendingInvocations.removeValue(forKey: invocationId) {
                                resultHandler(.failure(SignalRError.invocationFailed("Invocation timeout")))
                            }
                        }
                    }
                    
                } catch {
                    if let resultHandler = self.pendingInvocations.removeValue(forKey: invocationId) {
                        resultHandler(.failure(SignalRError.invocationFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    
    func on<T: Codable>(_ method: String, callback: @escaping (T) -> Void) {
        print("📥 SignalR Handler registered for: \(method)")
        
        eventHandlers[method] = { data in
            print("🔍 Attempting to decode \(method) data of type: \(type(of: data))")
            
            if let typedData = data as? T {
                print("✅ Direct type cast successful for \(method)")
                callback(typedData)
            } else if let jsonData = data as? String,
                      let dataObj = jsonData.data(using: .utf8),
                      let decodedData = try? JSONDecoder().decode(T.self, from: dataObj) {
                print("✅ String->JSON decode successful for \(method)")
                callback(decodedData)
            } else if let dictData = data as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dictData),
                      let decodedData = try? JSONDecoder().decode(T.self, from: jsonData) {
                print("✅ Dictionary->JSON decode successful for \(method)")
                callback(decodedData)
            } else {
                print("❌ Failed to decode \(method) data: \(data)")
                print("❌ Expected type: \(T.self)")
            }
        }
    }
    
    func clearEventHandlers() {
        eventHandlers.removeAll()
        print("🧹 Cleared all SignalR event handlers")
    }
    
    // MARK: - Hub Method Implementations
    // These methods use proper SignalR hub invocations over WebSocket
    
    /// Get contacts for a user
    /// - Parameter userId: The user ID as UUID
    /// - Returns: Array of SignalRUserDto objects
    func getContacts(userId: UUID) async throws -> [SignalRUserDto]? {
        return try await invoke("GetContacts", parameters: [userId.uuidString])
    }
    
    /// Get contact requests for a user
    /// - Parameters:
    ///   - userId: The user ID as UUID
    ///   - includeSent: Whether to include sent requests
    ///   - includeReceived: Whether to include received requests
    /// - Returns: Array of SignalRContactRequestDto objects
    func getContactRequests(userId: UUID, includeSent: Bool, includeReceived: Bool) async throws -> [SignalRContactRequestDto]? {
        return try await invoke("GetContactRequests", parameters: [userId.uuidString, includeSent, includeReceived])
    }
    
    /// Get chats for a user
    /// - Parameter userId: The user ID as UUID
    /// - Returns: Array of SignalRChatItemDto objects
    func getChatsForUser(userId: UUID) async throws -> [SignalRChatItemDto]? {
        return try await invoke("GetChatsForUser", parameters: [userId.uuidString])
    }
    
    /// Search for users
    /// - Parameters:
    ///   - requestingUserId: The ID of the user making the request
    ///   - searchQuery: The search query string
    ///   - maxResults: Maximum number of results to return
    /// - Returns: Array of SignalRUserDto objects
    func searchUsers(requestingUserId: UUID, searchQuery: String, maxResults: Int) async throws -> [SignalRUserDto]? {
        return try await invoke("SearchUsers", parameters: [requestingUserId.uuidString, searchQuery, maxResults])
    }
    
    /// Create a new user
    /// - Parameters:
    ///   - userId: The user ID as UUID
    ///   - username: Username
    ///   - email: Email address
    ///   - firstName: First name (optional)
    ///   - lastName: Last name (optional)
    /// - Returns: Created user as SignalRUserDto
    func createUser(userId: UUID, username: String, email: String, firstName: String?, lastName: String?) async throws -> SignalRUserDto? {
        return try await invoke("CreateUser", parameters: [userId.uuidString, username, email, firstName ?? "", lastName ?? ""])
    }
    
    /// Send a contact request
    /// - Parameters:
    ///   - fromUserId: The sender's user ID as UUID
    ///   - toUserId: The recipient's user ID as UUID
    /// - Returns: SignalRContactRequestResult object
    func sendContactRequest(fromUserId: UUID, toUserId: UUID) async throws -> SignalRContactRequestResult? {
        return try await invoke("SendContactRequest", parameters: [fromUserId.uuidString, toUserId.uuidString])
    }
    
    /// Respond to a contact request
    /// - Parameters:
    ///   - requestId: The contact request ID as UUID
    ///   - respondingUserId: The user responding to the request as UUID
    ///   - approve: Whether to approve the request
    /// - Returns: SignalRContactRequestResult object
    func respondToContactRequest(requestId: UUID, respondingUserId: UUID, approve: Bool) async throws -> SignalRContactRequestResult? {
        return try await invoke("RespondToContactRequest", parameters: [requestId.uuidString, respondingUserId.uuidString, approve])
    }
    
    /// Create a new conversation
    /// - Parameters:
    ///   - type: Conversation type (e.g., "Private", "Group")
    ///   - title: Optional conversation title
    ///   - participantIds: Array of participant user IDs as UUIDs
    /// - Returns: Created conversation
    func createConversation(type: String, title: String?, participantIds: [UUID]) async throws -> SignalRConversationDto? {
        let participantIdStrings = participantIds.map { $0.uuidString }
        return try await invoke("CreateConversation", parameters: [type, title as Any, participantIdStrings])
    }
    
    /// Join a conversation
    /// - Parameter conversationId: The conversation ID as UUID
    func joinConversation(conversationId: UUID) async throws {
        // These methods return void/null, so we handle them specially
        let _: Bool? = try await invoke("JoinConversation", parameters: [conversationId.uuidString])
    }
    
    /// Leave a conversation
    /// - Parameter conversationId: The conversation ID as UUID
    func leaveConversation(conversationId: UUID) async throws {
        // These methods return void/null, so we handle them specially
        let _: Bool? = try await invoke("LeaveConversation", parameters: [conversationId.uuidString])
    }
    
    /// Get messages for a conversation
    /// - Parameter conversationId: The conversation ID as UUID
    /// - Returns: Array of message objects
    func getMessagesForConversation(conversationId: UUID) async throws -> [SignalRMessageDto]? {
        return try await invoke("GetMessagesForConversation", parameters: [conversationId.uuidString])
    }
    
    /// Store a new message
    /// - Parameters:
    ///   - conversationId: The conversation ID as UUID
    ///   - userId: The sender's user ID as UUID
    ///   - content: Message content
    /// - Returns: Stored message
    func storeMessage(conversationId: UUID, userId: UUID, content: String) async throws -> SignalRMessageDto? {
        return try await invoke("StoreMessage", parameters: [conversationId.uuidString, userId.uuidString, content])
    }
    
    /// Notify that user is typing
    /// - Parameters:
    ///   - conversationId: The conversation ID as UUID
    ///   - userId: The user ID as UUID
    func notifyTyping(conversationId: UUID, userId: UUID) async throws {
        let _: String? = try await invoke("NotifyTyping", parameters: [conversationId.uuidString, userId.uuidString])
    }
    
    /// Notify that user stopped typing
    /// - Parameters:
    ///   - conversationId: The conversation ID as UUID
    ///   - userId: The user ID as UUID
    func notifyStoppedTyping(conversationId: UUID, userId: UUID) async throws {
        let _: String? = try await invoke("NotifyStoppedTyping", parameters: [conversationId.uuidString, userId.uuidString])
    }
    
    // MARK: - Real-time Event Handlers
    
    /// Register for receiving new messages
    func onMessageReceived(callback: @escaping (MessageDto) -> Void) {
        on("MessageReceived", callback: callback)
    }
    
    /// Register for typing notifications
    func onUserTyping(callback: @escaping (TypingNotificationDto) -> Void) {
        on("UserTyping", callback: callback)
    }
    
    /// Register for stopped typing notifications
    func onUserStoppedTyping(callback: @escaping (TypingNotificationDto) -> Void) {
        on("UserStoppedTyping", callback: callback)
    }
    
    /// Register for contact request notifications
    func onContactRequestReceived(callback: @escaping (SignalRContactRequestDto) -> Void) {
        on("ContactRequestReceived", callback: callback)
    }
    
    /// Register for contact request response notifications
    func onContactRequestResponded(callback: @escaping (ContactRequestResponseDto) -> Void) {
        on("ContactRequestResponded", callback: callback)
    }
    
    /// Register for user online status changes
    func onUserOnlineStatusChanged(callback: @escaping (UserOnlineStatusDto) -> Void) {
        on("UserOnlineStatusChanged", callback: callback)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let signalRReconnected = Notification.Name("signalRReconnected")
}

// MARK: - Public Data Transfer Objects

public struct SignalRUserDto: Codable, Identifiable {
    public let id: String
    public let username: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let profilePhotoUrl: String?
    public let status: String
    public let createdAt: String
    public let lastActiveAt: String?
    
    // Computed property to maintain compatibility with existing code expecting displayName
    public var displayName: String {
        if let firstName = firstName, !firstName.isEmpty,
           let lastName = lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if !username.isEmpty {
            return username
        } else {
            return email
        }
    }
    
    // Computed property for online status
    public var isOnline: Bool? {
        return status == "Available"
    }
    
    public init(id: String, username: String, email: String, firstName: String? = nil, lastName: String? = nil, profilePhotoUrl: String? = nil, status: String, createdAt: String, lastActiveAt: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.profilePhotoUrl = profilePhotoUrl
        self.status = status
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

public struct SignalRContactRequestDto: Codable, Identifiable {
    public let id: String
    public let fromUserId: String
    public let toUserId: String
    public let status: Int // 0 = Pending, 1 = Accepted, 2 = Denied
    public let requestedAt: String
    public let respondedAt: String?
    public let fromUser: SignalRUserDto
    public let toUser: SignalRUserDto
    
    // Computed properties for compatibility with existing code
    public var fromUserDisplayName: String {
        return fromUser.displayName
    }
    
    public var toUserDisplayName: String {
        return toUser.displayName
    }
    
    public var requestDate: Date {
        return ISO8601DateFormatter().date(from: requestedAt) ?? Date()
    }
    
    public var statusString: String {
        switch status {
        case 0: return "Pending"
        case 1: return "Accepted"
        case 2: return "Denied"
        default: return "Unknown"
        }
    }
    
    public init(id: String, fromUserId: String, toUserId: String, status: Int, requestedAt: String, respondedAt: String? = nil, fromUser: SignalRUserDto, toUser: SignalRUserDto) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.status = status
        self.requestedAt = requestedAt
        self.respondedAt = respondedAt
        self.fromUser = fromUser
        self.toUser = toUser
    }
}

public struct SignalRChatItemDto: Codable {
    public let conversationId: String
    public let name: String
    public let photoUrl: String?
    public let lastMessage: String?
    public let lastMessageTime: String?
    public let unreadCount: Int
    public let isPinned: Bool
    public let isGroup: Bool
    public let status: String
    public let otherUserId: String?
    
    /// Extracts the actual message text from JSON formatted lastMessage
    public var displayMessage: String {
        guard let lastMessage = lastMessage else { return "" }
        
        // Try to parse the JSON message
        if let data = lastMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
        // If parsing fails, return the original message
        return lastMessage
    }
    
    // Computed properties for compatibility with existing code
    public var title: String? {
        return name
    }
    
    public var type: String {
        return isGroup ? "GroupChat" : "DirectMessage"
    }
    
    public var participantCount: Int {
        return isGroup ? 2 : 2 // For now, assume 2 participants for direct messages
    }
    
    public var lastMessageDate: Date? {
        guard let lastMessageTime = lastMessageTime else { return nil }
        
        // Try different date formats
        let formatters = [
            ISO8601DateFormatter(),
            DateFormatter().apply { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().apply { $0.dateFormat = "h:mm a" }
        ]
        
        for formatter in formatters {
            if let date = (formatter as? ISO8601DateFormatter)?.date(from: lastMessageTime) ??
                          (formatter as? DateFormatter)?.date(from: lastMessageTime) {
                return date
            }
        }
        
        return nil
    }
    
    public init(conversationId: String, name: String, photoUrl: String? = nil, lastMessage: String? = nil, lastMessageTime: String? = nil, unreadCount: Int, isPinned: Bool, isGroup: Bool, status: String, otherUserId: String? = nil) {
        self.conversationId = conversationId
        self.name = name
        self.photoUrl = photoUrl
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isGroup = isGroup
        self.status = status
        self.otherUserId = otherUserId
    }
}

public struct SignalRContactRequestResult: Codable {
    public let success: Bool
    public let message: String?
    public let requestId: String?
    
    public init(success: Bool, message: String? = nil, requestId: String? = nil) {
        self.success = success
        self.message = message
        self.requestId = requestId
    }
}

// MARK: - Public Type Aliases for SignalR DTOs
// Note: ChatItemDto is defined in ModelsChatModels.swift
public typealias ContactRequestResult = SignalRContactRequestResult



public struct TypingNotificationDto: Codable {
    public let conversationId: String
    public let userId: String
    public let userDisplayName: String
    public let isTyping: Bool
    
    public init(conversationId: String, userId: String, userDisplayName: String, isTyping: Bool) {
        self.conversationId = conversationId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.isTyping = isTyping
    }
}

public struct ContactRequestResponseDto: Codable {
    public let requestId: String
    public let fromUserId: String
    public let toUserId: String
    public let approved: Bool
    public let responseDate: Date
    
    public init(requestId: String, fromUserId: String, toUserId: String, approved: Bool, responseDate: Date) {
        self.requestId = requestId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.approved = approved
        self.responseDate = responseDate
    }
}

public struct UserOnlineStatusDto: Codable {
    public let userId: String
    public let isOnline: Bool
    public let lastSeenDate: Date?
    
    public init(userId: String, isOnline: Bool, lastSeenDate: Date? = nil) {
        self.userId = userId
        self.isOnline = isOnline
        self.lastSeenDate = lastSeenDate
    }
}







// MARK: - SignalR Errors

enum SignalRError: Error, LocalizedError {
    case noAuthToken
    case notConnected
    case connectionFailed(String)
    case invocationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthToken:
            return "No authentication token available"
        case .notConnected:
            return "SignalR connection is not established"
        case .connectionFailed(let message):
            return "SignalR connection failed: \(message)"
        case .invocationFailed(let message):
            return "SignalR method invocation failed: \(message)"
        }
    }
}

// MARK: - SSL Certificate Handling for SignalR

class SignalRSSLDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        print("🔐 SignalR SSL Challenge received for: \(challenge.protectionSpace.host)")
        print("🔐 SignalR Authentication method: \(challenge.protectionSpace.authenticationMethod)")
        
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
        if host == "10.10.60.70" || host.hasSuffix(".axminc.com") {
            print("🔓 Accepting SignalR certificate for trusted host: \(host)")
            
            // For IP address connections, we need to validate the certificate more carefully
            if host == "10.10.60.70" {
                print("🔓 Accepting SignalR certificate for trusted IP address")
                
                // For our trusted internal IP, we'll bypass hostname verification
                // but still validate the certificate chain
                var secTrustResultType = SecTrustResultType.invalid
                let status = SecTrustEvaluate(serverTrust, &secTrustResultType)
                
                print("🔍 SignalR Trust evaluation status: \(status)")
                print("🔍 SignalR Trust result type: \(secTrustResultType.rawValue)")
                
                // Accept the certificate for our trusted IP regardless of hostname mismatch
                // This is safe because we explicitly trust this internal IP address
                print("✅ SignalR Certificate accepted for trusted IP (bypassing hostname check)")
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
            
            // Create credential with the server trust
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            
        } else {
            print("⚠️ Untrusted host for SignalR: \(host), using default handling")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
