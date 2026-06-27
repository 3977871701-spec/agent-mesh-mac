import Foundation
import SwiftUI
import Combine

@MainActor
class AgentMeshViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var agents: [Agent] = []
    @Published var pendingAgents: [Agent] = []
    @Published var activityItems: [ActivityItem] = []
    @Published var serverStats: ServerStats?
    @Published var connectionState: ConnectionState = .disconnected

    @Published var selectedAgent: Agent?
    @Published var messageText: String = ""
    @Published var showMessageSheet = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Services

    private let apiService = APIService.shared
    private let webSocketService = WebSocketService()
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        setupWebSocket()
    }

    // MARK: - Setup

    private func setupWebSocket() {
        webSocketService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        webSocketService.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showErrorMessage(error)
            }
            .store(in: &cancellables)

        webSocketService.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleWebSocketMessage(message)
            }
        }

        webSocketService.onStatusChange = { [weak self] agentId, status in
            Task { @MainActor in
                self?.handleStatusChange(agentId: agentId, status: status)
            }
        }
    }

    // MARK: - Connection

    func connect() {
        webSocketService.connect()
        startRefreshLoop()
    }

    func disconnect() {
        webSocketService.disconnect()
        stopRefreshLoop()
    }

    // MARK: - Refresh Loop

    private func startRefreshLoop() {
        stopRefreshLoop()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    private func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let agentsTask = apiService.fetchAgents()
            async let pendingTask = apiService.fetchPendingAgents()
            async let statsTask = apiService.fetchStats()

            let (fetchedAgents, fetchedPending, fetchedStats) = try await (agentsTask, pendingTask, statsTask)

            agents = fetchedAgents
            pendingAgents = fetchedPending
            serverStats = fetchedStats
        } catch {
            showErrorMessage("Failed to fetch data: \(error.localizedDescription)")
        }
    }

    // MARK: - WebSocket Message Handling

    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case "status_change":
            if let payload = message.payload,
               let agentId = payload["agent_id"] as? String,
               let statusStr = payload["status"] as? String,
               let status = AgentStatus(rawValue: statusStr) {
                handleStatusChange(agentId: agentId, status: status)
            }

        case "message":
            if let payload = message.payload {
                let msg = Message(
                    id: message.id ?? UUID().uuidString,
                    type: .message,
                    from: payload["from"] as? String ?? "",
                    to: payload["to"] as? String ?? "",
                    payload: payload["payload"] as? [String: AnyCodable],
                    timestamp: Date()
                )
                addActivityItem(ActivityItem(type: .message(message: msg)))
            }

        case "task_update":
            // Handle task updates
            break

        default:
            break
        }
    }

    private func handleStatusChange(agentId: String, status: AgentStatus) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            let agent = agents[index]
            agents[index].status = status

            if status == .offline {
                addActivityItem(ActivityItem(type: .agentOffline(agent: agent)))
            } else if status == .online {
                addActivityItem(ActivityItem(type: .agentOnline(agent: agent)))
            }
        } else if status == .online || status == .offline {
            // New agent, refresh list
            Task {
                await refresh()
            }
        }
    }

    // MARK: - Activity Feed

    private func addActivityItem(_ item: ActivityItem) {
        withAnimation(.easeInOut(duration: 0.3)) {
            activityItems.insert(item, at: 0)
            // Keep only last 100 items
            if activityItems.count > 100 {
                activityItems.removeLast()
            }
        }
    }

    // MARK: - Agent Actions

    func confirmAgent(_ agent: Agent) async {
        do {
            _ = try await apiService.confirmAgent(id: agent.id)
            pendingAgents.removeAll { $0.id == agent.id }
            await refresh()
            addActivityItem(ActivityItem(type: .systemMessage(text: "Agent \(agent.name) confirmed")))
        } catch {
            showErrorMessage("Failed to confirm agent: \(error.localizedDescription)")
        }
    }

    func rejectAgent(_ agent: Agent) async {
        do {
            try await apiService.rejectAgent(id: agent.id)
            pendingAgents.removeAll { $0.id == agent.id }
            addActivityItem(ActivityItem(type: .systemMessage(text: "Agent \(agent.name) rejected")))
        } catch {
            showErrorMessage("Failed to reject agent: \(error.localizedDescription)")
        }
    }

    // MARK: - Messaging

    func openMessageSheet(for agent: Agent) {
        selectedAgent = agent
        showMessageSheet = true
    }

    func sendMessage() {
        guard let agent = selectedAgent, !messageText.isEmpty else { return }

        webSocketService.sendMessage(to: agent.id, text: messageText)

        // Add to activity
        let message = Message(
            type: .message,
            from: "agentmesh-desktop",
            to: agent.id,
            payload: ["text": AnyCodable(messageText)],
            timestamp: Date()
        )
        addActivityItem(ActivityItem(type: .message(message: message)))

        messageText = ""
        showMessageSheet = false
    }

    // MARK: - Error Handling

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        addActivityItem(ActivityItem(type: .systemMessage(text: "Error: \(message)")))
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
