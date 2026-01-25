//
//  ChatModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

// MARK: - SignalR User Models

struct SignalRUserDto: Codable, Identifiable {
    let id: UUID
    let userName: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let companyId: String
    let isOnline: Bool
    let profileImageUrl: String?
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return userName
    }
    
    var initials: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased()
        }
        return String(userName.prefix(2)).uppercased()
    }
}

// MARK: - Contact Request Models

struct SignalRContactRequestDto: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let fromUser: SignalRUserDto
    let toUser: SignalRUserDto
    let status: ContactRequestStatus
    let createdAt: Date
    let respondedAt: Date?
}

enum ContactRequestStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
}

struct ContactRequestResponseDto: Codable {
    let requestId: UUID
    let accepted: Bool
}

// MARK: - Conversation Models

struct ConversationDto: Codable, Identifiable {
    let id: UUID
    let name: String?
    let type: ConversationType
    let participants: [SignalRUserDto]
    let createdAt: Date
    let lastMessageAt: Date?
    let lastMessage: String?
    let createdBy: UUID
    
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        
        // For private conversations, show the other participant's name
        if type == .private && participants.count == 2 {
            // Find the other participant (not the current user)
            // Note: In a real implementation, you'd compare against current user ID
            return participants.first?.displayName ?? "Unknown"
        }
        
        // For group conversations, show participant names
        let names = participants.prefix(3).map { $0.displayName }
        if participants.count > 3 {
            return names.joined(separator: ", ") + " and \(participants.count - 3) more"
        }
        return names.joined(separator: ", ")
    }
}

enum ConversationType: String, Codable, CaseIterable {
    case private = "Private"
    case group = "Group"
}

struct CreateConversationDto: Codable {
    let name: String?
    let type: ConversationType
    let participantIds: [UUID]
}

// MARK: - Chat List Models

struct ChatItemDto: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let name: String
    let lastMessage: String?
    let lastMessageTime: Date?
    let unreadCount: Int
    let participants: [SignalRUserDto]
    let type: ConversationType
    
    var displayName: String {
        if type == .private && participants.count >= 1 {
            return participants.first?.displayName ?? name
        }
        return name
    }
    
    var lastMessagePreview: String {
        return lastMessage ?? "No messages yet"
    }
    
    var formattedTime: String {
        guard let time = lastMessageTime else { return "" }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(time) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isYesterday(time) {
            return "Yesterday"
        } else if calendar.component(.weekOfYear, from: time) == calendar.component(.weekOfYear, from: Date()) {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = "M/d/yy"
        }
        
        return formatter.string(from: time)
    }
}

// MARK: - Message Models

struct MessageDto: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let senderName: String
    let content: String
    let timestamp: Date
    let messageType: MessageType
    let isEdited: Bool
    let editedAt: Date?
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(timestamp) {
            return "Today"
        } else if calendar.isYesterday(timestamp) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: timestamp)
        }
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text = "Text"
    case image = "Image"
    case file = "File"
    case system = "System"
}

struct SendMessageDto: Codable {
    let conversationId: UUID
    let content: String
    let messageType: MessageType
}

// MARK: - Message Grouping

struct MessageGroup: Identifiable {
    let id = UUID()
    let date: Date
    let messages: [MessageDto]
    
    var dateString: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            return "Today"
        } else if calendar.isYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Typing Indicators

struct TypingIndicator {
    let userId: UUID
    let userName: String
    let conversationId: UUID
    let isTyping: Bool
}

// MARK: - Search Models

struct UserSearchResult: Codable, Identifiable {
    let id: UUID
    let userName: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let profileImageUrl: String?
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return userName
    }
}

struct SearchUsersDto: Codable {
    let query: String
    let limit: Int
}