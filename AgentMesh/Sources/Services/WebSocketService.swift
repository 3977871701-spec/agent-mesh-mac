import Foundation

// MARK: - WebSocket Service

@MainActor
class WebSocketService: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private let reconnectDelay: TimeInterval = 3.0
    private let heartbeatInterval: TimeInterval = 30.0

    private let wsURL = "ws://localhost:18800"
    private var isManualDisconnect = false

    // Callbacks
    var onMessage: ((WebSocketMessage) -> Void)?
    var onStatusChange: ((String, AgentStatus) -> Void)?

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Management

    func connect() {
        guard connectionState == .disconnected || connectionState == .reconnecting else { return }

        isManualDisconnect = false
        connectionState = .connecting

        guard let url = URL(string: wsURL) else {
            lastError = "Invalid WebSocket URL"
            connectionState = .disconnected
            return
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Register with the server
        sendRegisterMessage()

        // Start receiving messages
        receiveMessage()

        connectionState = .connected
        startHeartbeat()
    }

    func disconnect() {
        isManualDisconnect = true
        connectionState = .disconnected
        stopHeartbeat()
        stopReconnectTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Message Handling

    private func sendRegisterMessage() {
        let registerMessage: [String: Any] = [
            "type": "register",
            "id": UUID().uuidString,
            "payload": [
                "id": "agentmesh-desktop",
                "name": "AgentMesh Desktop",
                "type": "desktop",
                "capabilities": ["messaging", "monitoring"]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: registerMessage),
           let string = String(data: data, encoding: .utf8) {
            send(string)
        }
    }

    func send(_ message: String) {
        guard connectionState == .connected else { return }

        webSocketTask?.send(.string(message)) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.lastError = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }

    func sendMessage(to: String, text: String) {
        let message: [String: Any] = [
            "type": "message",
            "id": UUID().uuidString,
            "to": to,
            "payload": ["text": text]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: message),
           let string = String(data: data, encoding: .utf8) {
            send(string)
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleReceivedText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleReceivedText(text)
                        }
                    @unknown default:
                        break
                    }

                    // Continue receiving
                    self.receiveMessage()

                case .failure(let error):
                    self.lastError = "Receive error: \(error.localizedDescription)"
                    self.handleDisconnection()
                }
            }
        }
    }

    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        // Parse message type
        if let wsMessage = WebSocketMessage.from(json: json) {
            onMessage?(wsMessage)
        }

        // Handle status changes
        if type == "status_change",
           let payload = json["payload"] as? [String: Any],
           let agentId = payload["agent_id"] as? String,
           let statusStr = payload["status"] as? String,
           let status = AgentStatus(rawValue: statusStr) {
            onStatusChange?(agentId, status)
        }
    }

    private func handleDisconnection() {
        guard !isManualDisconnect else { return }

        connectionState = .reconnecting
        stopHeartbeat()
        scheduleReconnect()
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendHeartbeat()
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendHeartbeat() {
        let heartbeat: [String: Any] = [
            "type": "heartbeat",
            "id": UUID().uuidString
        ]

        if let data = try? JSONSerialization.data(withJSONObject: heartbeat),
           let string = String(data: data, encoding: .utf8) {
            send(string)
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.connect()
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - WebSocket Message

struct WebSocketMessage {
    let type: String
    let id: String?
    let payload: [String: Any]?

    static func from(json: [String: Any]) -> WebSocketMessage? {
        guard let type = json["type"] as? String else { return nil }
        let id = json["id"] as? String
        let payload = json["payload"] as? [String: Any]
        return WebSocketMessage(type: type, id: id, payload: payload)
    }
}
