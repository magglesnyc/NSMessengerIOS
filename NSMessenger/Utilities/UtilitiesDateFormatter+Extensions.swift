//
//  DateFormatter+Extensions.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

extension DateFormatter {
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    static let messageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let lastMessageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    // Enhanced formatter for server timestamps
    static let serverTimestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Fallback formatter for server timestamps without fractional seconds
    static let serverTimestampFallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    // Specialized formatter for your server's specific format
    static let customServerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS" // 7 fractional digits, no timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Assume UTC
        return formatter
    }()
    
    // Alternative with 6 fractional digits
    static let customServerFormatter6: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    // Alternative with 5 fractional digits
    static let customServerFormatter5: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

extension Date {
    func timeString() -> String {
        return DateFormatter.messageTime.string(from: self)
    }
    
    func dateString() -> String {
        return DateFormatter.messageDate.string(from: self)
    }
    
    func lastMessageString() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return DateFormatter.messageTime.string(from: self)
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: self)
        }
    }
    
    /// Parse a server timestamp string with robust error handling
    static func fromServerTimestamp(_ timestamp: String) -> Date {
        // Normalize the input
        let trimmedTimestamp = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🕐 Parsing timestamp: '\(trimmedTimestamp)'")
        
        // Handle empty timestamps
        guard !trimmedTimestamp.isEmpty else {
            print("❌ Empty timestamp, using current date")
            return Date()
        }
        
        // First try the custom formatters for the specific server format (no timezone)
        // These handle timestamps like "2026-01-18T03:38:31.9583933"
        
        // Try with 7 fractional digits (most common in your data)
        if let date = DateFormatter.customServerFormatter.date(from: trimmedTimestamp) {
            print("✅ Parsed with custom format (7 digits): \(trimmedTimestamp) -> \(date)")
            return date
        }
        
        // Try with 6 fractional digits
        if let date = DateFormatter.customServerFormatter6.date(from: trimmedTimestamp) {
            print("✅ Parsed with custom format (6 digits): \(trimmedTimestamp) -> \(date)")
            return date
        }
        
        // Try with 5 fractional digits  
        if let date = DateFormatter.customServerFormatter5.date(from: trimmedTimestamp) {
            print("✅ Parsed with custom format (5 digits): \(trimmedTimestamp) -> \(date)")
            return date
        }
        
        // For backward compatibility, try adding 'Z' and using ISO8601
        var timestampToProcess = trimmedTimestamp
        if !trimmedTimestamp.contains("Z") && !trimmedTimestamp.contains("+") && !trimmedTimestamp.suffix(from: trimmedTimestamp.index(trimmedTimestamp.startIndex, offsetBy: min(10, trimmedTimestamp.count))).contains("-") {
            timestampToProcess = trimmedTimestamp + "Z"
            print("🕐 Added UTC timezone: \(timestampToProcess)")
        }
        
        // Try with fractional seconds first (ISO8601)
        if let date = DateFormatter.serverTimestamp.date(from: timestampToProcess) {
            print("✅ Parsed with ISO8601 fractional: \(timestampToProcess) -> \(date)")
            return date
        }
        
        // Try without fractional seconds (ISO8601)
        if let date = DateFormatter.serverTimestampFallback.date(from: timestampToProcess) {
            print("✅ Parsed with ISO8601 standard: \(timestampToProcess) -> \(date)")
            return date
        }
        
        // Try additional custom formats for edge cases
        let additionalFormatter = DateFormatter()
        additionalFormatter.locale = Locale(identifier: "en_US_POSIX")
        additionalFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Try with different fractional digit counts
        let fractionalFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss.SS",
            "yyyy-MM-dd'T'HH:mm:ss.S",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        
        for format in fractionalFormats {
            additionalFormatter.dateFormat = format
            if let date = additionalFormatter.date(from: trimmedTimestamp) {
                print("✅ Parsed with format '\(format)': \(trimmedTimestamp) -> \(date)")
                return date
            }
        }
        
        print("❌ Failed to parse timestamp: '\(trimmedTimestamp)', using current date")
        print("   Length: \(trimmedTimestamp.count)")
        print("   Contains T: \(trimmedTimestamp.contains("T"))")
        print("   Contains dot: \(trimmedTimestamp.contains("."))")
        
        return Date()
    }
}
