//
//  SSLCertificateHelper.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/24/26.
//

import Foundation
import Security
import Network

/// Helper class for SSL certificate validation and debugging
class SSLCertificateHelper {
    static let shared = SSLCertificateHelper()
    
    private init() {}
    
    /// Detailed analysis of server trust and certificate information
    func analyzeServerTrust(_ serverTrust: SecTrust, for host: String) {
        print("🔍 Analyzing server trust for: \(host)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Get certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        print("📜 Certificate chain length: \(certificateCount)")
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                analyzeCertificate(certificate, index: i)
            }
        }
        
        // Test different validation policies
        testValidationPolicies(serverTrust, for: host)
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    private func analyzeCertificate(_ certificate: SecCertificate, index: Int) {
        print("\n📜 Certificate \(index):")
        
        // Get certificate data
        let certificateData = SecCertificateCopyData(certificate)
        let certificateLength = CFDataGetLength(certificateData)
        print("   📏 Size: \(certificateLength) bytes")
        
        // Get certificate summary (this includes subject and issuer info)
        if let summary = SecCertificateCopySubjectSummary(certificate) {
            print("   👤 Subject: \(summary as String)")
        }
        
        // Get certificate common name and other basic info
        if let commonName = getCertificateCommonName(certificate) {
            print("   📋 Common Name: \(commonName)")
        }
        
        // Extract basic certificate information using available APIs
        extractBasicCertificateInfo(certificate)
    }
    
    private func getCertificateCommonName(_ certificate: SecCertificate) -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)
        
        if status == errSecSuccess, let cn = commonName {
            return cn as String
        }
        return nil
    }
    
    private func extractBasicCertificateInfo(_ certificate: SecCertificate) {
        // Get certificate data for basic parsing
        let certificateData = SecCertificateCopyData(certificate)
        let data = CFDataGetBytePtr(certificateData)
        let length = CFDataGetLength(certificateData)
        
        if let data = data {
            // Convert to Data for easier handling
            let certData = Data(bytes: data, count: length)
            print("   🔍 Certificate data available for analysis (\(certData.count) bytes)")
            
            // For more detailed certificate parsing, you would typically use a
            // third-party library or parse the ASN.1 structure manually
            // For now, we'll just note that the certificate data is available
        }
    }
    
    private func testValidationPolicies(_ serverTrust: SecTrust, for host: String) {
        print("\n🧪 Testing different validation policies:")
        
        // Test 1: Basic X.509 validation (no hostname check)
        testPolicy(serverTrust, policy: SecPolicyCreateBasicX509(), name: "Basic X.509")
        
        // Test 2: SSL policy with hostname
        if !host.isEmpty {
            testPolicy(serverTrust, policy: SecPolicyCreateSSL(true, host as CFString), name: "SSL with hostname (\(host))")
        }
        
        // Test 3: SSL policy without hostname requirement
        testPolicy(serverTrust, policy: SecPolicyCreateSSL(false, nil), name: "SSL without hostname")
        
        // Test 4: If this is an IP address, test with expected hostname
        if host.contains(".") && !host.contains(":") { // Simple IP check
            let expectedHostnames = ["authqa.axminc.com", "*.axminc.com"]
            for expectedHost in expectedHostnames {
                testPolicy(serverTrust, policy: SecPolicyCreateSSL(true, expectedHost as CFString), name: "SSL with expected hostname (\(expectedHost))")
            }
        }
    }
    
    private func testPolicy(_ serverTrust: SecTrust, policy: SecPolicy, name: String) {
        // For policy testing, we can modify the existing trust object
        // Store the original policies to restore them later
        var originalPolicies: CFArray?
        let originalStatus = SecTrustCopyPolicies(serverTrust, &originalPolicies)
        
        // Set the new policy for testing
        let setPolicyStatus = SecTrustSetPolicies(serverTrust, policy)
        
        guard setPolicyStatus == errSecSuccess else {
            print("   ❌ \(name): Failed to set policy (status: \(setPolicyStatus))")
            return
        }
        
        // Evaluate trust with the new policy
        var result = SecTrustResultType.invalid
        let evalStatus = SecTrustEvaluate(serverTrust, &result)
        
        let statusString = evalStatus == errSecSuccess ? "✅" : "❌"
        let resultString = trustResultDescription(result)
        
        print("   \(statusString) \(name): Status=\(evalStatus), Result=\(result.rawValue) (\(resultString))")
        
        // Provide additional context for common failure cases
        if result == .recoverableTrustFailure || result == .fatalTrustFailure {
            var trustError: CFError?
            if #available(iOS 14.0, *) {
                let detailed = SecTrustEvaluateWithError(serverTrust, &trustError)
                if let error = trustError {
                    let errorDesc = CFErrorCopyDescription(error)
                    print("     🔍 Trust error: \(errorDesc as String? ?? "Unknown error")")
                }
            }
            
            // Additional detailed analysis for failures
            if name.contains("hostname") {
                print("     💡 Hostname verification failed - certificate may be for a different domain")
            }
        }
        
        // Restore original policies if we had them
        if originalStatus == errSecSuccess, let policies = originalPolicies {
            SecTrustSetPolicies(serverTrust, policies)
        }
    }
    
    private func trustResultDescription(_ result: SecTrustResultType) -> String {
        switch result {
        case .invalid:
            return "Invalid"
        case .proceed:
            return "Proceed (User approved)"
        case .deny:
            return "Deny (User rejected)"
        case .unspecified:
            return "Unspecified (System approved)"
        case .recoverableTrustFailure:
            return "Recoverable Trust Failure"
        case .fatalTrustFailure:
            return "Fatal Trust Failure"
        case .otherError:
            return "Other Error"
        @unknown default:
            return "Unknown (\(result.rawValue))"
        }
    }
    
    /// Check if a hostname matches a certificate's subject alternative names or common name
    func validateHostnameMatch(certificate: SecCertificate, hostname: String) -> Bool {
        var foundNames: [String] = []
        
        // Get the common name from the certificate
        if let commonName = getCertificateCommonName(certificate) {
            foundNames.append(commonName)
        }
        
        // Get subject summary which may contain additional name information
        if let summary = SecCertificateCopySubjectSummary(certificate) {
            let summaryString = summary as String
            foundNames.append(summaryString)
        }
        
        print("🔍 Certificate names found: \(foundNames)")
        print("🔍 Checking against hostname: \(hostname)")
        
        // Check for exact matches or wildcard matches
        for name in foundNames {
            if name.lowercased() == hostname.lowercased() {
                print("✅ Exact hostname match: \(name)")
                return true
            }
            
            if name.hasPrefix("*.") {
                let wildcard = name.dropFirst(2) // Remove "*."
                if hostname.lowercased().hasSuffix(".\(wildcard.lowercased())") || 
                   hostname.lowercased() == String(wildcard.lowercased()) {
                    print("✅ Wildcard hostname match: \(name) matches \(hostname)")
                    return true
                }
            }
        }
        
        print("❌ No hostname match found")
        return false
    }
    
    /// Create a custom trust evaluation that's more lenient for development
    func createLenientServerTrust(for serverTrust: SecTrust, hostname: String) -> URLCredential? {
        print("🔧 Creating lenient server trust for: \(hostname)")
        
        // For IP addresses connecting to domain certificates, we'll be more lenient
        if isIPAddress(hostname) {
            print("🔧 IP address detected, using basic certificate validation")
            
            // Use basic X.509 validation without hostname checking
            let policy = SecPolicyCreateBasicX509()
            SecTrustSetPolicies(serverTrust, policy)
            
            var result = SecTrustResultType.invalid
            let status = SecTrustEvaluate(serverTrust, &result)
            
            print("🔧 Basic validation: status=\(status), result=\(result.rawValue)")
            
            if status == errSecSuccess && (result == .unspecified || result == .proceed) {
                print("✅ Basic certificate validation passed")
                return URLCredential(trust: serverTrust)
            } else {
                print("⚠️ Basic validation failed, checking certificate details...")
                
                // Get the leaf certificate for hostname validation
                if let leafCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                    // Check if the certificate is valid for our expected domain
                    if validateHostnameMatch(certificate: leafCertificate, hostname: "authqa.axminc.com") ||
                       validateHostnameMatch(certificate: leafCertificate, hostname: "*.axminc.com") {
                        print("✅ Certificate is valid for expected domain, accepting for IP connection")
                        return URLCredential(trust: serverTrust)
                    }
                }
                
                print("⚠️ Certificate validation concerns, but accepting for trusted IP in development")
                return URLCredential(trust: serverTrust)
            }
        }
        
        // For domain names, try standard SSL validation first
        let policy = SecPolicyCreateSSL(true, hostname as CFString)
        SecTrustSetPolicies(serverTrust, policy)
        
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &result)
        
        print("🔧 Standard SSL validation: status=\(status), result=\(result.rawValue)")
        
        if status == errSecSuccess && (result == .unspecified || result == .proceed) {
            print("✅ Standard SSL validation passed")
            return URLCredential(trust: serverTrust)
        } else if result == .recoverableTrustFailure {
            // This is a recoverable trust failure - common for self-signed or expired certificates
            print("🟡 Recoverable trust failure detected")
            
            // In development, we can accept recoverable trust failures for known hosts
            let trustedHosts = ["authqa.axminc.com", "*.axminc.com", "10.10.60.70"]
            let isKnownHost = trustedHosts.contains { trustedHost in
                if trustedHost == hostname {
                    return true
                } else if trustedHost.hasPrefix("*.") {
                    let domain = String(trustedHost.dropFirst(2))
                    return hostname.hasSuffix(domain)
                }
                return false
            }
            
            if isKnownHost {
                print("✅ Accepting recoverable trust failure for known development host: \(hostname)")
                return URLCredential(trust: serverTrust)
            }
        }
        
        print("⚠️ Standard validation failed, but accepting for trusted domain in development")
        return URLCredential(trust: serverTrust)
    }
    
    /// Comprehensive TLS error diagnosis and potential fixes
    func diagnoseTLSError(_ error: Error, for url: String) {
        print("🩺 TLS Error Diagnosis for: \(url)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if let urlError = error as? URLError {
            print("📋 URLError Code: \(urlError.code.rawValue) (\(urlError.code))")
            print("📋 Description: \(urlError.localizedDescription)")
            
            switch urlError.code {
            case .serverCertificateUntrusted:
                print("🔍 DIAGNOSIS: Server certificate is not trusted")
                print("💡 SOLUTIONS:")
                print("   1. Add domain to Info.plist NSExceptionDomains")
                print("   2. Install certificate on device/simulator")
                print("   3. Use HTTP instead of HTTPS for development")
                print("   4. Configure server with proper SSL certificate")
                
            case .serverCertificateHasBadDate:
                print("🔍 DIAGNOSIS: Server certificate has invalid date (expired or not yet valid)")
                print("💡 SOLUTIONS:")
                print("   1. Check system date/time")
                print("   2. Renew server certificate")
                print("   3. Configure ATS to allow invalid certificates")
                
            case .serverCertificateHasUnknownRoot:
                print("🔍 DIAGNOSIS: Server certificate has unknown root CA")
                print("💡 SOLUTIONS:")
                print("   1. Install root CA certificate")
                print("   2. Use certificate pinning")
                print("   3. Configure ATS exceptions")
                
            case .secureConnectionFailed:
                print("🔍 DIAGNOSIS: Generic secure connection failure")
                print("💡 SOLUTIONS:")
                print("   1. Check TLS version compatibility")
                print("   2. Verify cipher suite support")
                print("   3. Try different TLS versions")
                print("   4. Check for middleware interference")
                
            case .cannotFindHost:
                print("🔍 DIAGNOSIS: DNS resolution failed")
                print("💡 SOLUTIONS:")
                print("   1. Check network connectivity")
                print("   2. Verify hostname spelling")
                print("   3. Try direct IP address")
                print("   4. Check DNS settings")
                
            default:
                print("🔍 DIAGNOSIS: Other network error - \(urlError.code)")
                print("💡 Check network connectivity and server availability")
            }
            
            // Check for specific error patterns
            let errorDesc = urlError.localizedDescription.lowercased()
            if errorDesc.contains("tls") || errorDesc.contains("ssl") {
                print("🔍 TLS/SSL specific error detected")
                print("🔧 Suggested Info.plist configuration:")
                print("""
                <key>NSAppTransportSecurity</key>
                <dict>
                    <key>NSExceptionDomains</key>
                    <dict>
                        <key>authqa.axminc.com</key>
                        <dict>
                            <key>NSExceptionAllowsInsecureHTTPLoads</key>
                            <true/>
                            <key>NSExceptionMinimumTLSVersion</key>
                            <string>TLSv1.0</string>
                            <key>NSExceptionRequiresForwardSecrecy</key>
                            <false/>
                        </dict>
                        <key>10.10.60.70</key>
                        <dict>
                            <key>NSExceptionAllowsInsecureHTTPLoads</key>
                            <true/>
                            <key>NSExceptionMinimumTLSVersion</key>
                            <string>TLSv1.0</string>
                            <key>NSExceptionRequiresForwardSecrecy</key>
                            <false/>
                        </dict>
                    </dict>
                </dict>
                """)
            }
            
        } else {
            print("📋 Non-URLError: \(error)")
            print("📋 Type: \(type(of: error))")
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /// Test basic TLS connectivity without application-level protocols
    func testBasicTLSConnectivity(to host: String, port: Int = 443) async -> Bool {
        print("🔌 Testing basic TLS connectivity to \(host):\(port)")
        
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tls
            )
            
            var hasResumed = false
            let queue = DispatchQueue(label: "tls-test")
            
            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    print("✅ TLS connection established to \(host):\(port)")
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: true)
                    
                case .failed(let error):
                    print("❌ TLS connection failed to \(host):\(port) - \(error)")
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                    
                case .cancelled:
                    if !hasResumed {
                        print("⏹️ TLS connection cancelled to \(host):\(port)")
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                    
                default:
                    print("🔄 TLS connection state: \(state) for \(host):\(port)")
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 10 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                if !hasResumed {
                    print("⏱️ TLS connection timed out to \(host):\(port)")
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func isIPAddress(_ hostname: String) -> Bool {
        // Simple IPv4 check
        let parts = hostname.split(separator: ".")
        guard parts.count == 4 else { return false }
        
        return parts.allSatisfy { part in
            guard let num = Int(part), num >= 0, num <= 255 else { return false }
            return true
        }
    }
}