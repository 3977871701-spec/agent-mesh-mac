import Foundation

// MARK: - Agent Model

enum AgentStatus: String, Codable, CaseIterable {
    case online
    case offline
    case busy
    case pending

    var displayName: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .busy: return "Busy"
        case .pending: return "Pending"
        }
    }

    var color: String {
        switch self {
        case .online: return "green"
        case .offline: return "gray"
        case .busy: return "orange"
        case .pending: return "yellow"
        }
    }
}

struct Agent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var type: String
    var status: AgentStatus
    var capabilities: [String]
    var endpoint: String?
    var metadata: [String: String]?
    var lastSeen: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, type, status, capabilities, endpoint, metadata
        case lastSeen = "last_seen"
        case createdAt = "created_at"
    }

    init(id: String, name: String, type: String, status: AgentStatus = .offline, capabilities: [String] = [], endpoint: String? = nil, metadata: [String: String]? = nil, lastSeen: Date? = nil, createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.capabilities = capabilities
        self.endpoint = endpoint
        self.metadata = metadata
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        status = (try? container.decode(AgentStatus.self, forKey: .status)) ?? .offline
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)

        if let lastSeenString = try? container.decode(String.self, forKey: .lastSeen) {
            lastSeen = ISO8601DateFormatter().date(from: lastSeenString)
        } else {
            lastSeen = nil
        }

        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        } else {
            createdAt = nil
        }
    }

    static func == (lhs: Agent, rhs: Agent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Message Model

enum MessageType: String, Codable {
    case message
    case register
    case registerResponse = "register_response"
    case broadcast
    case task
    case taskUpdate = "task_update"
    case ack
    case heartbeat
    case discover
    case discoverResponse = "discover_response"
    case statusChange = "status_change"
    case error
}

struct Message: Identifiable, Codable {
    let id: String
    let type: MessageType
    let from: String
    let to: String
    let payload: [String: AnyCodable]?
    let timestamp: Date?
    let deliveredAt: Date?
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, from, to, payload, timestamp
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
    }

    init(id: String = UUID().uuidString, type: MessageType, from: String, to: String, payload: [String: AnyCodable]? = nil, timestamp: Date? = nil, deliveredAt: Date? = nil, readAt: Date? = nil) {
        self.id = id
        self.type = type
        self.from = from
        self.to = to
        self.payload = payload
        self.timestamp = timestamp
        self.deliveredAt = deliveredAt
        self.readAt = readAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(MessageType.self, forKey: .type) ?? .message
        from = try container.decodeIfPresent(String.self, forKey: .from) ?? ""
        to = try container.decodeIfPresent(String.self, forKey: .to) ?? ""
        payload = try container.decodeIfPresent([String: AnyCodable].self, forKey: .payload)

        if let ts = try? container.decode(String.self, forKey: .timestamp) {
            timestamp = ISO8601DateFormatter().date(from: ts)
        } else {
            timestamp = nil
        }

        if let da = try? container.decode(String.self, forKey: .deliveredAt) {
            deliveredAt = ISO8601DateFormatter().date(from: da)
        } else {
            deliveredAt = nil
        }

        if let ra = try? container.decode(String.self, forKey: .readAt) {
            readAt = ISO8601DateFormatter().date(from: ra)
        } else {
            readAt = nil
        }
    }

    var payloadText: String {
        guard let payload = payload,
              let textValue = payload["text"],
              let text = textValue.value as? String else {
            return ""
        }
        return text
    }
}

// MARK: - Task Model

enum TaskStatus: String, Codable {
    case pending
    case assigned
    case inProgress = "in_progress"
    case completed
    case failed
    case cancelled
}

struct Task: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var fromAgent: String
    var toAgent: String
    var status: TaskStatus
    var priority: String
    var result: [String: AnyCodable]?
    var deadline: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority, result, deadline
        case fromAgent = "from_agent"
        case toAgent = "to_agent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        fromAgent = try container.decodeIfPresent(String.self, forKey: .fromAgent) ?? ""
        toAgent = try container.decodeIfPresent(String.self, forKey: .toAgent) ?? ""
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .pending
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "normal"

        result = try container.decodeIfPresent([String: AnyCodable].self, forKey: .result)

        if let dl = try? container.decode(String.self, forKey: .deadline) {
            deadline = ISO8601DateFormatter().date(from: dl)
        } else {
            deadline = nil
        }

        if let ca = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: ca)
        } else {
            createdAt = nil
        }

        if let ua = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: ua)
        } else {
            updatedAt = nil
        }
    }
}

// MARK: - Activity Feed Item

enum ActivityType {
    case agentOnline(agent: Agent)
    case agentOffline(agent: Agent)
    case message(message: Message)
    case taskCreated(task: Task)
    case taskUpdated(task: Task)
    case taskCompleted(task: Task)
    case systemMessage(text: String)
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: ActivityType

    var title: String {
        switch type {
        case .agentOnline(let agent):
            return "Agent Online"
        case .agentOffline(let agent):
            return "Agent Offline"
        case .message:
            return "Message"
        case .taskCreated:
            return "Task Created"
        case .taskUpdated:
            return "Task Updated"
        case .taskCompleted:
            return "Task Completed"
        case .systemMessage:
            return "System"
        }
    }

    var description: String {
        switch type {
        case .agentOnline(let agent):
            return "\(agent.name) (\(agent.type)) connected"
        case .agentOffline(let agent):
            return "\(agent.name) (\(agent.type)) disconnected"
        case .message(let message):
            return "\(message.from) -> \(message.to)"
        case .taskCreated(let task):
            return task.title
        case .taskUpdated(let task):
            return "\(task.title) [\(task.status.rawValue)]"
        case .taskCompleted(let task):
            return "\(task.title) completed"
        case .systemMessage(let text):
            return text
        }
    }

    var icon: String {
        switch type {
        case .agentOnline: return "checkmark.circle.fill"
        case .agentOffline: return "xmark.circle.fill"
        case .message: return "message.fill"
        case .taskCreated, .taskUpdated: return "square.stack.fill"
        case .taskCompleted: return "checkmark.seal.fill"
        case .systemMessage: return "gear"
        }
    }
}

// MARK: - Server Stats

struct ServerStats: Codable {
    var agents: AgentStats
    var onlineCount: Int
    var queueSize: Int
    var taskCount: Int

    enum CodingKeys: String, CodingKey {
        case agents
        case onlineCount = "online_count"
        case queueSize = "queue_size"
        case taskCount = "task_count"
    }
}

struct AgentStats: Codable {
    var total: Int
    var online: Int
    var offline: Int
    var pending: Int
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
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
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            try container.encode(String(describing: value))
        }
    }
}
