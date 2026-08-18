import Foundation

/// 全局聊天室 WebSocket 客户端(基于 URLSessionWebSocketTask)。
/// 连接后先发 auth(token),通过后发 join 进入聊天。
final class ChatClient: NSObject, ObservableObject, URLSessionWebSocketDelegate {

    enum ChatEvent {
        case opened
        case authed(User)
        case authFail(String)
        case message(String)   // 原始 JSON 字符串(history/chat/system)
        case closed
        case failure(Error)
    }

    var onEvent: ((ChatEvent) -> Void)?

    /// 实时连接状态(后台重连循环读取此值)
    var isConnected = false

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var token: String = ""
    private var name: String = ""

    private let wsURL = URL(string: "ws://120.48.161.149:18700/ws")!

    func connect(token: String, name: String) {
        self.token = token
        self.name = name

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session?.webSocketTask(with: wsURL)
        task?.resume()
        receiveLoop()
    }

    // MARK: - 接收循环
    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                self.isConnected = false
                DispatchQueue.main.async { self.onEvent?(.failure(err)) }
            case .success(let msg):
                switch msg {
                case .string(let text):
                    self.handle(text: text)
                case .data(let data):
                    if let t = String(data: data, encoding: .utf8) { self.handle(text: t) }
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) else { return }
        let type = obj["type"] as? String ?? ""
        switch type {
        case "auth_ok":
            if let u = obj["user"] as? [String: Any], let user = User(from: u) {
                send(json: ["type": "join", "name": name])
                DispatchQueue.main.async { self.onEvent?(.authed(user)) }
            }
        case "auth_fail":
            let msg = obj["msg"] as? String ?? "登录已失效"
            DispatchQueue.main.async { self.onEvent?(.authFail(msg)) }
        default:
            DispatchQueue.main.async { self.onEvent?(.message(text)) }
        }
    }

    func sendText(_ text: String) {
        send(json: ["type": "chat", "text": text])
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    func close() {
        isConnected = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        isConnected = true
        // 连接建立后发送认证
        send(json: ["type": "auth", "token": token])
        DispatchQueue.main.async { self.onEvent?(.opened) }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        DispatchQueue.main.async {
            self.onEvent?(.closed)
        }
    }
}
