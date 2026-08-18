import Foundation

// MARK: - 启动崩溃自检(侧载环境无 Mac 也能拿到崩溃信息)
// 崩溃后写入 Documents/last_crash.txt,下次启动读取并在登录页顶部红条展示,
// 用户截图发我即可定位(无需 Mac / 无需导出 .ips)。
final class CrashReporter: ObservableObject {
    static let shared = CrashReporter()

    @Published var lastCrash: String?

    private static let fileName = "last_crash.txt"
    private static var crashFD: Int32 = -1

    private static func fileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private init() {
        // 启动时读取上一次崩溃记录(只展示一次),读完即删
        if let s = try? String(contentsOf: CrashReporter.fileURL(), encoding: .utf8), !s.isEmpty {
            lastCrash = s
            try? FileManager.default.removeItem(at: CrashReporter.fileURL())
        }
        install()
    }

    /// 在 App 初始化时调用一次,安装异常/信号捕获
    func install() {
        CrashReporter.crashFD = open((CrashReporter.fileURL().path as NSString).utf8String,
                                     O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        NSSetUncaughtExceptionHandler { exc in
            let symbols = (exc.callStackSymbols as? [String]) ?? []
            let stack = symbols.joined(separator: "\n")
            let text = "EXCEPTION \(exc.name.rawValue): \(exc.reason ?? "?")\n\n\(stack)"
            try? text.write(to: CrashReporter.fileURL(), atomically: true, encoding: .utf8)
        }
        signal(SIGABRT, CrashReporter.signalHandler)
        signal(SIGSEGV, CrashReporter.signalHandler)
        signal(SIGTRAP, CrashReporter.signalHandler)
        signal(SIGILL,  CrashReporter.signalHandler)
        signal(SIGBUS,  CrashReporter.signalHandler)
        signal(SIGFPE,  CrashReporter.signalHandler)
    }

    // 信号回调:仅记录信号类型与回溯地址(异步信号安全写法),随后恢复原处理并 re-raise
    // 让系统照常终止并记录崩溃。地址可在下次启动时符号化。
    private static let signalHandler: @convention(c) (Int32) -> Void = { sig in
        writeLiteral("SIGNAL ")
        writeInt(sig)
        writeByte(10)
        // 恢复默认处理并重新触发,确保系统记录崩溃
        signal(sig, SIG_DFL)
        raise(sig)
    }

    // ---- 异步信号安全的最小写文件辅助 ----
    private static func writeByte(_ b: CChar) {
        var b = b
        _ = write(crashFD, &b, 1)
    }
    private static func writeLiteral(_ s: String) {
        for c in s.utf8 { writeByte(CChar(bitPattern: c)) }
    }
    private static func writeInt(_ v: Int32) {
        var n = v
        if n < 0 { writeByte(45); n = -n } // '-'
        if n == 0 { writeByte(48); return }
        var digits: [CChar] = []
        var t = n
        while t > 0 { digits.insert(CChar(48 + (t % 10)), at: 0); t /= 10 }
        for d in digits { writeByte(d) }
    }
}
