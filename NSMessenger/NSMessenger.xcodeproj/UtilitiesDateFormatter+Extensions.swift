//
//  DateFormatter+Extensions.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

extension DateFormatter {
    
    // MARK: - Shared Formatters
    
    static let shared = DateFormatter()
    
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let iso8601Simple: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: - Chat Message Formatters
    
    static let messageTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    static let messageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let chatListTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    static let chatListDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter
    }()
    
    // MARK: - Relative Date Formatting
    
    static let relativeDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

extension Date {
    
    // MARK: - Chat-Specific Formatting
    
    var chatTimeString: String {
        DateFormatter.messageTime.string(from: self)
    }
    
    var chatDateString: String {
        let calendar = Calendar.current
        
        if calendar.isToday(self) {
            return "Today"
        } else if calendar.isYesterday(self) {
            return "Yesterday"
        } else {
            return DateFormatter.messageDate.string(from: self)
        }
    }
    
    var chatListTimeString: String {
        let calendar = Calendar.current
        
        if calendar.isToday(self) {
            return DateFormatter.chatListTime.string(from: self)
        } else if calendar.isYesterday(self) {
            return "Yesterday"
        } else if calendar.component(.weekOfYear, from: self) == calendar.component(.weekOfYear, from: Date()) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        } else {
            return DateFormatter.chatListDate.string(from: self)
        }
    }
    
    // MARK: - ISO8601 Parsing
    
    static func fromISO8601String(_ dateString: String) -> Date? {
        // Try with microseconds first
        if let date = DateFormatter.iso8601.date(from: dateString) {
            return date
        }
        
        // Try without microseconds
        if let date = DateFormatter.iso8601Simple.date(from: dateString) {
            return date
        }
        
        // Try with built-in ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: dateString)
    }
    
    // MARK: - Relative Time
    
    var relativeTimeString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            return DateFormatter.relativeDate.string(from: self)
        }
    }
    
    // MARK: - Time Grouping
    
    func isSameDay(as otherDate: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: otherDate)
    }
    
    func isSameMinute(as otherDate: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        let components2 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: otherDate)
        return components1 == components2
    }
    
    func isWithinMinutes(_ minutes: Int, of otherDate: Date) -> Bool {
        let timeInterval = abs(self.timeIntervalSince(otherDate))
        return timeInterval <= Double(minutes * 60)
    }
}

// MARK: - Message Grouping Utilities

extension Array where Element == MessageDto {
    
    func groupedByDate() -> [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        
        return grouped.compactMap { (date, messages) in
            MessageGroup(date: date, messages: messages.sorted { $0.timestamp < $1.timestamp })
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - JSON Date Decoding

extension JSONDecoder {
    
    static let withISO8601Dates: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = Date.fromISO8601String(dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Could not decode date from string: \(dateString)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    
    static let withISO8601Dates: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let dateString = DateFormatter.iso8601.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }
        return encoder
    }()
}