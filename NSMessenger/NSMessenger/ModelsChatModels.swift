//
//  ChatModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import Foundation

// MARK: - User Models

public struct UserDto: Codable, Identifiable {
    public let id: UUID
    public let username: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let profilePhotoUrl: String
    public let status: String
    public let createdAt: Date
    public let lastActiveAt: Date?

    public var displayName: String {
        if !firstName.isEmpty {
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        return username.isEmpty ? email : username
    }
    
    public init(id: UUID, username: String, email: String, firstName: String, lastName: String, profilePhotoUrl: String, status: String, createdAt: Date, lastActiveAt: Date? = nil) {
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

public struct UpdateProfileResult: Codable {
    public let success: Bool
    public let userId: UUID
    public let firstName: String?
    public let lastName: String?
    public let profilePhotoUrl: String?
    public let status: String?
    public let errorMessage: String?
}

// MARK: - Conversation Models

public struct LocalConversationDto: Codable, Identifiable {
    public let id: UUID
    public let type: String
    public let title: String?
    public let createdAt: Date
    public let lastMessageAt: Date?
    
    public init(id: UUID, type: String, title: String? = nil, createdAt: Date, lastMessageAt: Date? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
    }
}

public struct ParticipantDto: Codable, Identifiable {
    public let id: UUID
    public let conversationId: UUID
    public let userId: UUID
    public let joinedAt: Date
    public let isAdmin: Bool
    public let user: UserDto?
    
    public init(id: UUID, conversationId: UUID, userId: UUID, joinedAt: Date, isAdmin: Bool, user: UserDto? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.joinedAt = joinedAt
        self.isAdmin = isAdmin
        self.user = user
    }
}

// MARK: - Message Models

// SignalR DTOs (from server)
public struct SignalRMessageDto: Codable {
    public let id: Int              // Server returns numeric ID
    public let conversationId: String
    public let senderId: String
    public let senderName: String   // Server uses senderName, not senderDisplayName
    public let content: String
    public let sentAt: String       // Server returns string, we'll convert to Date
    public let isEdited: Bool
    public let editedAt: String?
    public let isDeleted: Bool
    
    // Computed properties for compatibility
    public var idString: String {
        return String(id)
    }
    
    public var senderDisplayName: String {
        return senderName
    }
    
    public var sentDate: Date {
        return Date.fromServerTimestamp(sentAt)
    }
    
    public var messageType: String {
        return "Text" // Default to text for now
    }
    
    public init(id: Int, conversationId: String, senderId: String, senderName: String, content: String, sentAt: String, isEdited: Bool, editedAt: String? = nil, isDeleted: Bool) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.sentAt = sentAt
        self.isEdited = isEdited
        self.editedAt = editedAt
        self.isDeleted = isDeleted
    }
}

public struct MessageDto: Codable, Identifiable {
    public let id: String
    public let conversationId: String
    public let senderId: String
    public let senderDisplayName: String
    public let content: String
    public let sentDate: Date
    public let messageType: String // "Text", "Image", etc.
    
    // Initializer that can accept SignalRMessageDto
    public init(from signalRMessage: SignalRMessageDto) {
        self.id = signalRMessage.idString
        self.conversationId = signalRMessage.conversationId
        self.senderId = signalRMessage.senderId
        self.senderDisplayName = signalRMessage.senderDisplayName
        self.content = signalRMessage.content
        self.sentDate = signalRMessage.sentDate
        self.messageType = signalRMessage.messageType
    }
    
    public init(id: String, conversationId: String, senderId: String, senderDisplayName: String, content: String, sentDate: Date, messageType: String) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderDisplayName = senderDisplayName
        self.content = content
        self.sentDate = sentDate
        self.messageType = messageType
    }
}

public struct ConversationDto: Codable, Identifiable {
    public let id: String
    public let title: String?
    public let type: String
    public let participantIds: [String]
    public let createdDate: Date
    
    public init(id: String, title: String? = nil, type: String, participantIds: [String], createdDate: Date) {
        self.id = id
        self.title = title
        self.type = type
        self.participantIds = participantIds
        self.createdDate = createdDate
    }
}

public struct SignalRConversationDto: Codable {
    public let id: String
    public let title: String?
    public let type: String
    public let participantIds: [String]
    public let createdDate: Date
    
    public init(id: String, title: String? = nil, type: String, participantIds: [String], createdDate: Date) {
        self.id = id
        self.title = title
        self.type = type
        self.participantIds = participantIds
        self.createdDate = createdDate
    }
}

public struct LocalMessageDto: Codable, Identifiable {
    public let id: Int64
    public let conversationId: UUID
    public let senderId: UUID
    public let content: String
    public let sentAt: Date
    public let isEdited: Bool
    public let editedAt: Date?
    public let isDeleted: Bool
    public let senderName: String
}

// MARK: - Contact Models

struct ContactRequestDto: Codable, Identifiable {
    let id: UUID
    let fromUserId: String
    let toUserId: String
    let status: String
    let requestedAt: String
    let fromUserDisplayName: String
    let fromUserEmail: String?
    let fromUserPhotoUrl: String?
}

struct LocalContactRequestDto: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let status: Int  // 0 = Pending, 1 = Approved, 2 = Declined
    let requestedAt: Date
    let respondedAt: Date?
    let fromUser: UserDto?
    let toUser: UserDto?
}

struct ContactRequestResultDto: Codable {
    let success: Bool
    let requestId: UUID
    let message: String
}

// MARK: - Chat List Models

struct ChatItemDto: Codable, Identifiable {
    var id: UUID { conversationId }
    let conversationId: UUID
    let name: String
    let photoUrl: String
    let lastMessage: String
    let lastMessageTime: String
    let unreadCount: Int
    let isPinned: Bool
    let isGroup: Bool
    let status: String
    let otherUserId: UUID?
    
    /// Extracts the actual message text from JSON formatted lastMessage
    var displayMessage: String {
        // Try to parse the JSON message
        if let data = lastMessage.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
        // If parsing fails, return the original message
        return lastMessage
    }
}

// MARK: - SignalR Event Models

struct ContactRequestResponseData: Codable {
    let requestId: String
    let approved: Bool
}

struct TypingNotificationData: Codable {
    let userId: String
    let conversationId: String?
}

// MARK: - Enums

enum PresenceStatus: Int, Codable {
    case online = 0
    case away = 1
    case busy = 2
    case offline = 3
}

enum UserStatusType: String, CaseIterable {
    case available = "Available"
    case away = "Away" 
    case offline = "Offline"
    case busy = "Busy"
}

enum ContactRequestStatus: Int {
    case pending = 0
    case approved = 1
    case declined = 2
}

// MARK: - UI Models

struct ChatUser: Identifiable {
    let id: String
    let name: String
    let photo: String
    var lastMessage: String
    var time: String
    var unreadCount: Int
    let isPinned: Bool
    let isGroup: Bool
    let status: String
}

struct Contact: Identifiable {
    let id: String
    let name: String
    let photo: String
    let status: String
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    let isFromCurrentUser: Bool
    let isRead: Bool
}

struct MessageGroup: Identifiable, Equatable {
    var id: String { dateLabel }
    let dateLabel: String
    var messages: [ChatMessage]
}

// MARK: - Extensions

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
