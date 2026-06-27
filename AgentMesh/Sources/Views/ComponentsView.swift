import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var viewModel: AgentMeshViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Server Stats Cards
                HStack(spacing: 20) {
                    StatCard(
                        title: "Online Agents",
                        value: "\(viewModel.serverStats?.onlineCount ?? 0)",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .green
                    )

                    StatCard(
                        title: "Total Tasks",
                        value: "\(viewModel.serverStats?.taskCount ?? 0)",
                        icon: "checklist",
                        color: .blue
                    )

                    StatCard(
                        title: "Queue Size",
                        value: "\(viewModel.serverStats?.queueSize ?? 0)",
                        icon: "tray.full.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Pending Agents",
                        value: "\(viewModel.pendingAgents.count)",
                        icon: "clock.fill",
                        color: .yellow
                    )
                }

                // Agent Status Breakdown
                if let stats = viewModel.serverStats {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Agent Registry")
                            .font(.headline)

                        HStack(spacing: 30) {
                            AgentStatusBadge(
                                label: "Online",
                                count: stats.agents.online,
                                color: .green
                            )
                            AgentStatusBadge(
                                label: "Offline",
                                count: stats.agents.offline,
                                color: .gray
                            )
                            AgentStatusBadge(
                                label: "Pending",
                                count: stats.agents.pending,
                                color: .yellow
                            )
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Agent List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connected Agents")
                        .font(.headline)

                    if viewModel.agents.isEmpty {
                        ContentUnavailableView(
                            "No Agents",
                            systemImage: "antenna.radiowaves.left.and.right.slash",
                            description: Text("No agents are currently connected")
                        )
                        .frame(height: 200)
                    } else {
                        ForEach(viewModel.agents) { agent in
                            AgentInfoRow(agent: agent)
                            if agent.id != viewModel.agents.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Agent Status Badge

struct AgentStatusBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 70)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Agent Info Row

struct AgentInfoRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Icon
            Image(systemName: agentIcon)
                .foregroundStyle(statusColor)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(agent.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !agent.capabilities.isEmpty {
                        Text(agent.capabilities.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Last seen
            if let lastSeen = agent.lastSeen {
                Text(lastSeen, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch agent.status {
        case .online: return .green
        case .offline: return .gray
        case .busy: return .orange
        case .pending: return .yellow
        }
    }

    private var agentIcon: String {
        switch agent.type {
        case "hermes": return "brain.head.profile"
        case "openclaw": return "pawprint.fill"
        case "codex": return "cpu"
        default: return "desktopcomputer"
        }
    }
}

// MARK: - Activity Feed View

struct ActivityFeedView: View {
    @ObservedObject var viewModel: AgentMeshViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.activityItems.isEmpty {
                    ContentUnavailableView(
                        "No Activity",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Activity will appear here when agents connect or send messages")
                    )
                    .frame(height: 300)
                } else {
                    ForEach(viewModel.activityItems) { item in
                        ActivityItemRow(item: item)
                        Divider()
                    }
                }
            }
        }
        .navigationTitle("Activity Feed")
    }
}

// MARK: - Activity Item Row

struct ActivityItemRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var iconColor: Color {
        switch item.type {
        case .agentOnline: return .green
        case .agentOffline: return .red
        case .message: return .blue
        case .taskCreated: return .orange
        case .taskUpdated: return .purple
        case .taskCompleted: return .green
        case .systemMessage: return .gray
        }
    }
}

// MARK: - Message Sheet View

struct MessageSheetView: View {
    @ObservedObject var viewModel: AgentMeshViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Send Message")
                    .font(.headline)

                Spacer()

                Button(action: { viewModel.showMessageSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            // Recipient
            if let agent = viewModel.selectedAgent {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("To:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(agent.name)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Message input
            TextField("Enter your message...", text: $viewModel.messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($isTextFieldFocused)

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    viewModel.showMessageSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Send") {
                    viewModel.sendMessage()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.messageText.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 300)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
