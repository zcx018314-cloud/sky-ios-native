import SwiftUI
import Foundation

/// 聊天室页(对齐 Android ChatScreen.kt:WebSocket + 自动重连 + 消息气泡)
struct ChatScreen: View {
    var onAuthExpired: () -> Void

    @StateObject private var client = ChatClient()

    @State private var messages: [ChatMessage] = []
    @State private var connected = false
    @State private var authed = false
    @State private var input = ""
    @State private var statusText = "连接中…"

    static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var myUid: Int { AuthStore.shared.user?.id ?? -1 }
    private var myName: String {
        AuthStore.shared.user?.nickname ?? AuthStore.shared.user?.username ?? "?"
    }

    var body: some View {
        let myName = self.myName
        VStack(spacing: 0) {
            // ---------- 顶部 ----------
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("聊天室")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFF9FE8FF)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .ambientCyan.opacity(0.5), radius: 10, y: 2)
                    Circle()
                        .fill(authed
                              ? LinearGradient(colors: [.ambientCyan, Color(hex: 0xFF00FFA3)], startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Color(hex: 0xFFF0A050), Color(hex: 0xFFE05555)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 9, height: 9)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(authed ? .ambientCyan : .textFaint)
                }
                HStack(spacing: 8) {
                    Text("我:").font(.system(size: 12)).foregroundColor(.textFaint)
                    Text(myName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text("(在「我的」页修改)").font(.system(size: 10)).foregroundColor(.textFaint)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 50).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 50))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // ---------- 消息列表 ----------
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if messages.isEmpty {
                            Text("还没有消息,来打个招呼吧")
                                .font(.system(size: 12))
                                .foregroundColor(.textFaint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(messages) { msg in
                                MessageBubble(msg: msg, myUid: myUid, myName: myName, mySeed: AuthStore.shared.user?.avatarSeed ?? "")
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .task(id: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            // ---------- 底部输入 ----------
            HStack(spacing: 10) {
                GlassTextField(value: input, onValueChange: { input = $0 }, placeholder: authed ? "说点什么…" : "正在连接…")
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(authed ? .white : .textFaint)
                        .frame(width: 54, height: 54)
                        .background(authed
                                    ? LinearGradient(colors: [.accentStart, .accentEnd], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                        .clipShape(Circle())
                }
                .disabled(!authed)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .task {
            client.onEvent = { event in
                handleEvent(event)
            }
            while !Task.isCancelled {
                guard let tok = AuthStore.shared.token else { break }
                if !client.isConnected {
                    client.connect(token: tok, name: myName)
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .onDisappear { client.close() }
    }

    private func handleEvent(_ event: ChatClient.ChatEvent) {
        switch event {
        case .opened:
            connected = true
            statusText = "认证中…"
        case .authed:
            authed = true
            statusText = "已连接"
        case .authFail(let msg):
            statusText = msg
            onAuthExpired()
        case .message(let json):
            parse(json)
        case .closed:
            connected = false
            authed = false
            statusText = "连接断开,重连中…"
        case .failure:
            connected = false
            authed = false
            statusText = "连接失败,3 秒后重连…"
        }
    }

    private func parse(_ json: String) {
        guard let data = json.data(using: .utf8),
              let o = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) else { return }
        let type = o["type"] as? String ?? ""
        switch type {
        case "history":
            guard let arr = o["messages"] as? [[String: Any]] else { return }
            var list: [ChatMessage] = []
            for m in arr { if let msg = parseMsg(m) { list.append(msg) } }
            messages = list
        case "chat":
            guard let msg = parseMsg(o) else { return }
            messages.append(msg)
        case "system":
            guard let text = o["text"] as? String else { return }
            if text.contains("加入了聊天室") || text.contains("离开了聊天室") { return }
            let ts = (o["ts"] as? Double) ?? Date().timeIntervalSince1970
            messages.append(ChatMessage(kind: "system", from: "", fromId: 0, seed: "", text: text, ts: ts, isSelf: false))
        default:
            break
        }
    }

    private func parseMsg(_ m: [String: Any]) -> ChatMessage? {
        let kind = (m["kind"] as? String) ?? "chat"
        if kind == "system",
           let t = m["text"] as? String,
           (t.contains("加入了聊天室") || t.contains("离开了聊天室")) {
            return nil
        }
        let fromId = (m["from_id"] as? Int) ?? -1
        let text = (m["text"] as? String) ?? ""
        let ts = (m["ts"] as? Double) ?? Date().timeIntervalSince1970
        let from = (m["from"] as? String) ?? ""
        let seed = (m["seed"] as? String) ?? ""
        let isSelf = (kind == "chat") && (fromId == myUid)
        return ChatMessage(kind: kind, from: from, fromId: fromId, seed: seed, text: text, ts: ts, isSelf: isSelf)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, authed else { return }
        client.sendText(text)
        input = ""
    }
}

// MARK: - 消息气泡(带头像)
private struct MessageBubble: View {
    let msg: ChatMessage
    let myUid: Int
    let myName: String
    let mySeed: String

    var body: some View {
        if msg.kind == "system" {
            Text(msg.text)
                .font(.system(size: 11))
                .foregroundColor(.textFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        } else {
            let isSelf = msg.isSelf
            HStack(alignment: .bottom, spacing: 8) {
                if !isSelf {
                    ChatAvatar(fromId: msg.fromId, name: msg.from, seed: msg.seed, size: 34)
                }
                VStack(alignment: isSelf ? .trailing : .leading, spacing: 2) {
                    if !isSelf {
                        Text(msg.from)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.ambientCyan)
                    }
                    Text(msg.text)
                        .font(.system(size: 14))
                        .foregroundColor(isSelf ? .white : .textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelf
                                    ? LinearGradient(colors: [.accentStart, .accentEnd], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                            isSelf
                                ? LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text(ChatScreen.timeFmt.string(from: Date(timeIntervalSince1970: msg.ts)))
                        .font(.system(size: 9))
                        .foregroundColor(isSelf ? .white.opacity(0.6) : .textFaint)
                        .padding(.top, 2)
                }
                if isSelf {
                    ChatAvatar(fromId: myUid, name: myName, seed: mySeed, size: 34)
                }
            }
            .frame(maxWidth: .infinity, alignment: isSelf ? .trailing : .leading)
        }
    }
}
