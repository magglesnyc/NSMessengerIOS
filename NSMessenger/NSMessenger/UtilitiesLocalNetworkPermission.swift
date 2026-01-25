//
//  LocalNetworkPermission.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/20/26.
//

import Foundation
import Network

/// Utility to help trigger and manage Local Network permissions
class LocalNetworkPermission {
    static let shared = LocalNetworkPermission()
    
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var hasRequestedPermission = false
    private var permissionGranted = false
    
    private init() {}
    
    /// Triggers the Local Network permission dialog by attempting to connect to a local address
    /// This should be called before making requests to local IP addresses
    func requestPermissionIfNeeded(for host: String = "10.10.60.70") async {
        // Don't spam permission requests
        guard !hasRequestedPermission else {
            print("🔓 Local network permission already requested, skipping...")
            return
        }
        
        hasRequestedPermission = true
        print("🔓 Requesting local network permission for host: \(host)...")
        
        // Try multiple approaches to trigger the permission dialog
        await requestPermissionWithMultiplePorts(host: host)
        
        // Give the system time to show the permission dialog and for user to respond
        try? await Task.sleep(for: .seconds(2))
        
        // Test if permission was granted
        let hasAccess = await checkLocalNetworkAccess(for: host)
        permissionGranted = hasAccess
        
        print("🔓 Local network permission request completed. Access granted: \(hasAccess)")
    }
    
    /// Try multiple connection approaches to trigger permission dialog
    private func requestPermissionWithMultiplePorts(host: String) async {
        // Common ports to try for triggering the permission dialog
        // Server uses host headers on standard HTTP/HTTPS ports
        let portsToTry: [(port: UInt16, name: String)] = [
            (443, "HTTPS (Host Headers)"),  // Primary port for virtual hosting
            (80, "HTTP (Host Headers)"),    // Secondary port for virtual hosting
            (8080, "HTTP-Alt"),
            (8443, "HTTPS-Alt")
        ]
        
        for (port, name) in portsToTry {
            print("🔓 Attempting \(name) connection to \(host):\(port)...")
            
            let success = await attemptConnection(host: host, port: port)
            if success {
                print("✅ Successfully connected to \(host):\(port) (\(name))")
                // Don't break - we want to test multiple ports for permission triggering
            }
            
            // Small delay between attempts
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
    
    /// Attempt a single connection to trigger permission
    private func attemptConnection(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
            var hasResumed = false
            
            let resumeOnce = { (success: Bool) in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: success)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ Connection established to \(host):\(port)")
                    resumeOnce(true)
                case .failed(let error):
                    print("🔴 Connection failed to \(host):\(port) - \(error)")
                    resumeOnce(false)
                case .cancelled:
                    if !hasResumed {
                        resumeOnce(false)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if !hasResumed {
                    print("⏰ Connection timeout for \(host):\(port)")
                    resumeOnce(false)
                }
            }
        }
    }
    
    /// Check if local network access is available for a specific host
    /// Updated to check the actual ports used by the server with host headers
    func checkLocalNetworkAccess(for host: String = "10.10.60.70") async -> Bool {
        // Test both HTTPS and HTTP ports since server uses host headers on both
        let httpsAccess = await testConnection(host: host, port: 443)
        if httpsAccess {
            return true
        }
        
        let httpAccess = await testConnection(host: host, port: 80)
        return httpAccess
    }
    
    /// Test connection without triggering permission dialog
    private func testConnection(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
            var hasResumed = false
            
            let resumeOnce = { (success: Bool) in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: success)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce(true)
                case .failed(let error):
                    // Check if this is specifically a local network permission error
                    let errorString = error.localizedDescription.lowercased()
                    if errorString.contains("local network") || errorString.contains("prohibited") {
                        print("🚫 Local network access denied for \(host):\(port)")
                    }
                    resumeOnce(false)
                case .cancelled:
                    if !hasResumed {
                        resumeOnce(false)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Shorter timeout for testing
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if !hasResumed {
                    resumeOnce(false)
                }
            }
        }
    }
    
    /// Check current permission status without making new requests
    var isPermissionGranted: Bool {
        return permissionGranted
    }
    
    /// Force a permission re-request (useful when permission was denied)
    func forcePermissionRequest(for host: String = "10.10.60.70") async {
        hasRequestedPermission = false
        permissionGranted = false
        await requestPermissionIfNeeded(for: host)
    }
    
    /// Reset permission request state (useful for testing)
    func resetPermissionState() {
        hasRequestedPermission = false
        permissionGranted = false
    }
    
    /// Check if a URL uses a local IP address
    func isLocalIPAddress(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return false
        }
        
        // Check for private IP ranges
        let privateRanges = [
            "10.",           // 10.0.0.0/8
            "192.168.",      // 192.168.0.0/16
            "172.16.",       // 172.16.0.0/12 (simplified check)
            "127.",          // 127.0.0.0/8 (localhost)
            "localhost"
        ]
        
        return privateRanges.contains { host.hasPrefix($0) }
    }
    
    /// Test if server supports host header routing by trying with proper hostname
    func testHostHeaderRouting(hostname: String, ipAddress: String, port: UInt16 = 443) async -> Bool {
        print("🔍 Testing host header routing for \(hostname) -> \(ipAddress):\(port)")
        
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(ipAddress), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
            var hasResumed = false
            
            let resumeOnce = { (success: Bool) in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: success)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ TCP connection established to \(ipAddress):\(port) for host header test")
                    resumeOnce(true)
                case .failed(let error):
                    print("🔴 TCP connection failed to \(ipAddress):\(port) - \(error)")
                    resumeOnce(false)
                case .cancelled:
                    if !hasResumed {
                        resumeOnce(false)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if !hasResumed {
                    print("⏰ Host header test timeout for \(ipAddress):\(port)")
                    resumeOnce(false)
                }
            }
        }
    }
    
    /// Starts monitoring network path changes with local network awareness
    func startMonitoring() {
        monitor = NWPathMonitor()
        monitor?.start(queue: queue)
        
        monitor?.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("📡 Network is available")
                
                // Check if local network is available
                if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                    print("📡 Local network interface available")
                }
            } else {
                print("📡 Network is not available")
                self?.permissionGranted = false
            }
            
            // Log detailed path information for debugging
            print("📡 Network path details:")
            print("   Status: \(path.status)")
            print("   Expensive: \(path.isExpensive)")
            print("   Constrained: \(path.isConstrained)")
            
            if let availableInterfaces = path.availableInterfaces.first {
                print("   Interface: \(availableInterfaces.name) (\(availableInterfaces.type))")
            }
        }
    }
    
    /// Stops monitoring network changes
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }
}
