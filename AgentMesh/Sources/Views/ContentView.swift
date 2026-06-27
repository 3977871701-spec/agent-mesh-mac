import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AgentMeshViewModel()
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            DetailView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionStatusView(state: viewModel.connectionState)

                Button(action: { Task { await viewModel.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $viewModel.showMessageSheet) {
            MessageSheetView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var viewModel: AgentMeshViewModel

    var body: some View {
        List {
            Section("Overview") {
                NavigationLink(value: "stats") {
                    Label("Server Stats", systemImage: "chart.bar.fill")
                }
                NavigationLink(value: "activity") {
                    Label("Activity Feed", systemImage: "list.bullet.rectangle")
                }
            }

            Section("Agents (\(viewModel.agents.count))") {
                ForEach(viewModel.agents) { agent in
                    AgentRowView(agent: agent, viewModel: viewModel)
                }
            }

            if !viewModel.pendingAgents.isEmpty {
                Section("Pending (\(viewModel.pendingAgents.count))") {
                    ForEach(viewModel.pendingAgents) { agent in
                        PendingAgentRowView(agent: agent, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Agent Mesh")
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var viewModel: AgentMeshViewModel
    @State private var selectedDetail: String? = "stats"

    var body: some View {
        VStack {
            switch selectedDetail {
            case "activity":
                ActivityFeedView(viewModel: viewModel)
            default:
                StatsView(viewModel: viewModel)
            }
        }
        .navigationTitle(selectedDetail == "activity" ? "Activity Feed" : "Server Statistics")
        .navigationDestination(for: String.self) { value in
            if value == "stats" {
                StatsView(viewModel: viewModel)
            } else if value == "activity" {
                ActivityFeedView(viewModel: viewModel)
            } else {
                AgentDetailView(agent: viewModel.agents.first { $0.id == value } ?? viewModel.agents[0])
            }
        }
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(state.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch state {
        case .connected: return .green
        case .connecting, .reconnecting: return .yellow
        case .disconnected: return .red
        }
    }
}

// MARK: - Agent Row View

struct AgentRowView: View {
    let agent: Agent
    @ObservedObject var viewModel: AgentMeshViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: agentIcon)
                .foregroundStyle(agentColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(agent.type)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(agent.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(agentColor.opacity(0.15))
                .foregroundStyle(agentColor)
                .clipShape(Capsule())

            Button(action: { viewModel.openMessageSheet(for: agent) }) {
                Image(systemName: "envelope")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Send message")
        }
        .padding(.vertical, 4)
    }

    private var agentIcon: String {
        switch agent.type {
        case "hermes": return "brain.head.profile"
        case "openclaw": return "pawprint.fill"
        case "codex": return "cpu"
        default: return "desktopcomputer"
        }
    }

    private var agentColor: Color {
        switch agent.status {
        case .online: return .green
        case .offline: return .gray
        case .busy: return .orange
        case .pending: return .yellow
        }
    }
}

// MARK: - Pending Agent Row View

struct PendingAgentRowView: View {
    let agent: Agent
    @ObservedObject var viewModel: AgentMeshViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(agent.type)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { Task { await viewModel.confirmAgent(agent) } }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.borderless)
            .help("Confirm agent")

            Button(action: { Task { await viewModel.rejectAgent(agent) } }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Reject agent")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    let agent: Agent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text(agent.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(agent.type)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Info
                Group {
                    LabeledContent("ID", value: agent.id)
                    LabeledContent("Type", value: agent.type)
                    LabeledContent("Status", value: agent.status.displayName)

                    if let endpoint = agent.endpoint {
                        LabeledContent("Endpoint", value: endpoint)
                    }
                }

                if !agent.capabilities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capabilities")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(agent.capabilities, id: \.self) { cap in
                                Text(cap)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(agent.name)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            height = y + rowHeight
        }
    }
}
