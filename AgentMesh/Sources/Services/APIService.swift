import Foundation

// MARK: - Connection State

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting

    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "red"
        case .connecting, .reconnecting: return "yellow"
        case .connected: return "green"
        }
    }
}

// MARK: - APIService

actor APIService {
    static let shared = APIService()

    private let baseURL = "http://localhost:18801"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Agents

    func fetchAgents() async throws -> [Agent] {
        let url = URL(string: "\(baseURL)/api/agents")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AgentsResponse.self, from: data)
        return response.agents
    }

    func fetchPendingAgents() async throws -> [Agent] {
        let url = URL(string: "\(baseURL)/api/agents/pending")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(AgentsResponse.self, from: data)
        return response.agents
    }

    func confirmAgent(id: String) async throws -> Agent {
        let url = URL(string: "\(baseURL)/api/agents/\(id)/confirm")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ConfirmResponse.self, from: data)
        return response.agent
    }

    func rejectAgent(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/agents/\(id)/reject")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await session.data(for: request)
    }

    // MARK: - Messages

    func fetchMessages(agentId: String) async throws -> [Message] {
        let url = URL(string: "\(baseURL)/api/messages/\(agentId)")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
        return response.messages
    }

    // MARK: - Tasks

    func fetchTasks() async throws -> [Task] {
        let url = URL(string: "\(baseURL)/api/tasks")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TasksResponse.self, from: data)
        return response.tasks
    }

    // MARK: - Stats

    func fetchStats() async throws -> ServerStats {
        let url = URL(string: "\(baseURL)/api/stats")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ServerStats.self, from: data)
    }

    // MARK: - Send Message

    func sendMessage(to: String, payload: [String: Any]) async throws {
        let url = URL(string: "\(baseURL)/api/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "type": "message",
            "to": to,
            "payload": payload
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await session.data(for: request)
    }
}

// MARK: - Response Types

struct AgentsResponse: Codable {
    let agents: [Agent]
}

struct ConfirmResponse: Codable {
    let status: String
    let agent: Agent
}

struct MessagesResponse: Codable {
    let messages: [Message]
}

struct TasksResponse: Codable {
    let tasks: [Task]
}
