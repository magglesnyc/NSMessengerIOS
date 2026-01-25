//
//  TimestampTestPlayground.swift
//  NSMessenger - Test file for timestamp parsing
//
//  Created for debugging timestamp issues
//
//  swiftlint:disable all
//  This is a test/debugging file - warnings are suppressed

import Foundation

// Mock structures for testing (simplified versions)
struct TestSignalRMessageDto {
    let id: Int
    let conversationId: String
    let senderId: String
    let senderName: String
    let content: String
    let sentAt: String
    let isEdited: Bool
    let editedAt: String?
    let isDeleted: Bool
    
    var sentDate: Date {
        return Date.fromServerTimestamp(sentAt)
    }
}

struct TestMessageDto {
    let id: String
    let conversationId: String
    let senderId: String
    let senderDisplayName: String
    let content: String
    let sentDate: Date
    let messageType: String
    
    init(from signalRMessage: TestSignalRMessageDto) {
        self.id = String(signalRMessage.id)
        self.conversationId = signalRMessage.conversationId
        self.senderId = signalRMessage.senderId
        self.senderDisplayName = signalRMessage.senderName
        self.content = signalRMessage.content
        self.sentDate = signalRMessage.sentDate
        self.messageType = "Text"
    }
}

// Test the timestamp parsing with actual server data
func testTimestampParsing() {
    let actualServerMessages = [
        ("2026-01-18T03:38:31.9583933", "go again.  werd"),
        ("2026-01-18T03:39:10.7523933", "I don't know"),
        ("2026-01-18T03:39:36.6605807", "i see your updates immediately"),
        ("2026-01-18T03:39:59.03923", "this is the new message i am talking about"),
        ("2026-01-18T03:41:36.240513", "I am really really tired"),
        ("2026-01-18T03:43:03.7290523", "Error message..."),
        ("2026-01-18T04:08:02.3386478", "timma.....")
    ]
    
    print("🧪 Testing timestamp parsing with actual server data:")
    print("📊 Current time: \(Date())")
    print("")
    
    for (index, (timestamp, content)) in actualServerMessages.enumerated() {
        print("💬 Message \(index + 1): \"\(content)\"")
        print("   Raw server timestamp: \(timestamp)")
        
        // Test with current parsing logic
        let parsedDate = Date.fromServerTimestamp(timestamp)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: parsedDate)
        
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let fullString = formatter.string(from: parsedDate)
        
        print("   Parsed date: \(parsedDate)")
        print("   Display time: \(timeString)")
        print("   Full display: \(fullString)")
        
        // Check if the parsed time makes sense (should be around 3-4 AM)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: parsedDate)
        let minute = calendar.component(.minute, from: parsedDate)
        
        print("   Extracted hour: \(hour), minute: \(minute)")
        
        if hour >= 3 && hour <= 4 {
            print("   ✅ Timestamp looks correct for expected time range")
        } else {
            print("   ⚠️ Timestamp may be incorrect - expected 3-4 AM range")
        }
        print("")
    }
    
    // Test timezone handling
    print("🌍 Testing timezone information:")
    let testTimestamp = "2026-01-18T03:38:31.9583933"
    let utcTimestamp = testTimestamp + "Z"
    
    print("   Original: \(testTimestamp)")
    print("   With UTC: \(utcTimestamp)")
    
    let originalParsed = Date.fromServerTimestamp(testTimestamp)
    let utcParsed = Date.fromServerTimestamp(utcTimestamp)
    
    let timezoneFormatter = DateFormatter()
    timezoneFormatter.dateStyle = .medium
    timezoneFormatter.timeStyle = .medium
    
    timezoneFormatter.timeZone = TimeZone.current
    print("   Original parsed (local tz): \(timezoneFormatter.string(from: originalParsed))")
    print("   UTC parsed (local tz): \(timezoneFormatter.string(from: utcParsed))")
    
    timezoneFormatter.timeZone = TimeZone(abbreviation: "UTC")
    print("   Original parsed (UTC): \(timezoneFormatter.string(from: originalParsed))")
    print("   UTC parsed (UTC): \(timezoneFormatter.string(from: utcParsed))")
}

// Additional test for message conversion
func testMessageConversion() {
    print("\n🔄 Testing SignalRMessageDto conversion:")
    
    // Simulate a SignalRMessageDto with actual server data
    let signalRMessage = TestSignalRMessageDto(
        id: 31,
        conversationId: "4214ab90-d49f-4de6-a433-839f3b14b553",
        senderId: "12b22322-5d60-435a-9d8f-896d168cabfb",
        senderName: "allen",
        content: "go again.  werd",
        sentAt: "2026-01-18T03:38:31.9583933",
        isEdited: false,
        editedAt: nil,
        isDeleted: false
    )
    
    let messageDto = TestMessageDto(from: signalRMessage)
    
    print("📤 SignalR Message:")
    print("   ID: \(signalRMessage.id)")
    print("   SentAt string: \(signalRMessage.sentAt)")
    print("   Computed sentDate: \(signalRMessage.sentDate)")
    
    print("📥 Converted MessageDto:")
    print("   ID: \(messageDto.id)")
    print("   SentDate: \(messageDto.sentDate)")
    
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    print("   Time string: \(formatter.string(from: messageDto.sentDate))")
    
    // Compare the timestamps
    if signalRMessage.sentDate == messageDto.sentDate {
        print("   ✅ Timestamps match perfectly")
    } else {
        print("   ❌ Timestamp mismatch!")
        print("     SignalR: \(signalRMessage.sentDate)")
        print("     DTO: \(messageDto.sentDate)")
    }
}

// Main function to run all tests
func runTimestampTests() {
    testTimestampParsing()
    testMessageConversion()
}

// To run the tests, call runTimestampTests() from somewhere appropriate,
// like in a test method, app delegate, or playground page
