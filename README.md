# AgentMesh macOS

## 项目简介

AgentMesh macOS 是一款原生 macOS 桌面应用，用于监控和管理分布式 AI Agent 网络（Agent Mesh）。它通过 WebSocket 实时接收 Agent 状态变更，通过 REST API 获取 Agent 列表、统计数据等信息，并提供直观的 SwiftUI 界面让用户与 Agent 进行交互——包括发送消息、确认/拒绝待审核的 Agent、查看服务器统计和活动日志等。

应用连接到 AgentMesh 后端服务器（默认 WebSocket 端口 `ws://localhost:18800`，REST API 端口 `http://localhost:18801`），以桌面客户端的角色注册到 Mesh 网络中，支持实时消息收发和心跳保活。

## 功能特性

### Agent 管理
- **实时 Agent 列表**：侧边栏展示所有已注册 Agent，显示名称、类型、状态（Online/Offline/Busy/Pending）
- **Agent 详情查看**：点击 Agent 可查看 ID、类型、状态、Endpoint、能力列表等详细信息
- **待审核 Agent 审批**：支持确认（Confirm）或拒绝（Reject）新加入的 Pending 状态 Agent
- **类型图标识别**：根据 Agent 类型（hermes/openclaw/codex/desktop）显示不同图标

### 实时通信
- **WebSocket 连接**：自动连接后端 WebSocket 服务，支持断线自动重连（3 秒间隔）
- **心跳保活**：每 30 秒发送心跳消息维持连接
- **消息收发**：通过 WebSocket 向指定 Agent 发送文本消息
- **状态变更推送**：实时接收 Agent 上下线状态变更通知

### 数据展示
- **服务器统计面板**：在线 Agent 数、总任务数、队列大小、待审核 Agent 数
- **Agent 注册统计**：按状态分类的 Agent 数量统计（Online/Offline/Pending）
- **活动日志**：实时展示系统事件（Agent 上下线、消息收发、任务创建/完成、系统消息），最多保留 100 条
- **自动刷新**：每 5 秒自动拉取最新数据

### 用户界面
- **NavigationSplitView 布局**：左侧侧边栏 + 右侧详情面板
- **连接状态指示器**：工具栏显示当前连接状态（Connected/Connecting/Disconnected/Reconnecting）
- **消息发送面板**：Sheet 弹窗输入消息内容并发送
- **错误提示**：异常信息通过 Alert 弹窗展示
- **深色/浅色模式**：跟随系统配色方案

## 技术栈

| 技术 | 说明 |
|------|------|
| **语言** | Swift 5.9 |
| **平台** | macOS 14.0+ (Sonoma) |
| **UI 框架** | SwiftUI + AppKit（NSWindow/NSHostingView） |
| **架构模式** | MVVM（ViewModel + ObservableObject） |
| **网络层** | URLSessionWebSocketTask（WebSocket）+ URLSession（REST API） |
| **并发** | Swift Concurrency（async/await）+ Combine |
| **项目管理** | XcodeGen（project.yml） |
| **Xcode 版本** | 15.0+ |

### 项目结构

```
agent-mesh-mac/
├── project.yml                          # XcodeGen 项目配置
├── AgentMesh.xcodeproj/                 # Xcode 工程文件
└── AgentMesh/
    ├── Sources/
    │   ├── App/
    │   │   ├── main.swift               # 应用入口
    │   │   └── AppDelegate.swift        # NSApplicationDelegate，窗口管理
    │   ├── Models/
    │   │   └── Models.swift             # 数据模型（Agent/Message/Task/ActivityItem）
    │   ├── ViewModels/
    │   │   └── AgentMeshViewModel.swift # MVVM ViewModel，业务逻辑中心
    │   ├── Services/
    │   │   ├── APIService.swift         # REST API 客户端（actor，线程安全）
    │   │   └── WebSocketService.swift   # WebSocket 客户端（连接/重连/心跳）
    │   └── Views/
    │       ├── ContentView.swift        # 主视图（侧边栏/详情/Agent 行/消息面板）
    │       └── ComponentsView.swift     # 组件视图（统计卡片/活动日志/消息面板）
    └── Resources/
        ├── Info.plist                   # 应用配置（本地网络权限等）
        ├── AgentMesh.entitlements       # 权限声明（网络客户端）
        └── Assets.xcassets/             # 图标资源
```

### 核心数据模型

- **Agent**：Agent 实体（id/name/type/status/capabilities/endpoint/metadata）
- **Message**：消息实体（type/from/to/payload/timestamp），支持 12 种消息类型
- **Task**：任务实体（title/description/status/priority/deadline）
- **ServerStats**：服务器统计（Agent 计数/队列大小/任务数）
- **ActivityItem**：活动日志条目（7 种事件类型）

## 使用方法

### 环境要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0 或更高版本（用于构建）

### 构建与运行

```bash
# 1. 使用 XcodeGen 生成 Xcode 项目（如已存在 .xcodeproj 则跳过）
cd /Users/xylei/Projects/agent-mesh-mac
xcodegen generate

# 2. 用 Xcode 打开项目
open AgentMesh.xcodeproj

# 3. 在 Xcode 中按 Cmd+R 运行
```

### 启动后端服务

应用需要连接 AgentMesh 后端服务器。请确保以下服务已启动：

- **WebSocket 服务**：`ws://localhost:18800`
- **REST API 服务**：`http://localhost:18801`

### API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/agents` | 获取已注册 Agent 列表 |
| GET | `/api/agents/pending` | 获取待审核 Agent 列表 |
| POST | `/api/agents/{id}/confirm` | 确认 Agent |
| POST | `/api/agents/{id}/reject` | 拒绝 Agent |
| GET | `/api/messages/{agentId}` | 获取指定 Agent 的消息 |
| GET | `/api/tasks` | 获取任务列表 |
| GET | `/api/stats` | 获取服务器统计 |
| POST | `/api/send` | 发送消息 |

### 使用流程

1. 启动应用后，它会自动连接到后端 WebSocket 服务并注册为 `agentmesh-desktop` 客户端
2. 侧边栏左侧展示所有已注册的 Agent 列表和待审核 Agent
3. 点击侧边栏中的 "Server Stats" 查看服务器统计面板
4. 点击侧边栏中的 "Activity Feed" 查看实时活动日志
5. 点击 Agent 行右侧的信封图标可向该 Agent 发送消息
6. 对 Pending 状态的 Agent，点击确认或拒绝按钮进行审批
7. 工具栏右侧的刷新按钮可手动拉取最新数据
