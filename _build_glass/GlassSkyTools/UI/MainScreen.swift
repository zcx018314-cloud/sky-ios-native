import SwiftUI
import Foundation

/// 主容器:未登录显示登录页,已登录显示底部三栏(工具/聊天/我的)
struct MainScreen: View {
    @State private var loggedIn: Bool = AuthStore.shared.isLoggedIn
    @State private var tab = 0

    var body: some View {
        if !loggedIn {
            LoginScreen(onSuccess: {
                loggedIn = true
                tab = 0
            })
        } else {
            ZStack {
                GlassBackground()
                VStack(spacing: 0) {
                    switch tab {
                    case 0:
                        ToolsScreen()
                    case 1:
                        ChatScreen(onAuthExpired: { loggedIn = false })
                    default:
                        SettingsScreen(onLoggedOut: { loggedIn = false })
                    }
                    GlassBottomNav(selected: tab, onSelect: { tab = $0 })
                }
            }
        }
    }
}

// MARK: - 工具页(账号管理 + 身高 + 光翼)
private let UUID_REGEX = try! NSRegularExpression(
    pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

struct ToolsScreen: View {
    @State private var accounts: [Account] = AccountStore.shared.accounts
    @State private var currentId: String? = AccountStore.shared.currentId

    @State private var idInput = ""
    @State private var noteInput = ""
    @State private var heightInput = ""

    @State private var busy = false
    @State private var busyAction = ""

    @State private var hint: (String, Bool)? = nil
    @State private var hintVisible = false

    var body: some View {
        let accountId = AuthStore.shared.user?.id.description ?? ""

        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    AppHeader()

                    // ---------- 账号管理 ----------
                    GlassCard {
                        GlassCardTitle(text: "账号管理")
                        GlassTextField(value: idInput, onValueChange: { idInput = $0 }, placeholder: "粘贴 UUID 游戏ID")
                        GlassTextField(value: noteInput, onValueChange: { noteInput = $0 }, placeholder: "账号备注(如大号/小号)")
                        HStack(spacing: 10) {
                            GlassButton(text: "添加账号", onClick: addAccount, enabled: true)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .layoutPriority(1.4)
                            GlassOutlineButton(text: "清空全部", onClick: {
                                if !accounts.isEmpty {
                                    AccountStore.shared.clearAll()
                                    refreshAccounts()
                                    showHint("已清空全部账号", false)
                                }
                            })
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        AccountList(
                            accounts: accounts,
                            currentId: currentId,
                            onSelect: { id in
                                AccountStore.shared.currentId = id
                                currentId = id
                            },
                            onDelete: { id in
                                AccountStore.shared.removeAccount(id: id)
                                refreshAccounts()
                            }
                        )
                    }

                    // ---------- 修改身高 ----------
                    GlassCard(glowColor: .ambientCyan) {
                        GlassCardTitle(text: "修改身高", tint: .ambientCyan)
                        GlassTextField(value: heightInput, onValueChange: { heightInput = $0 }, placeholder: "输入身高值(-1.4 ~ 16.6)")
                        HStack(spacing: 10) {
                            GlassButton(text: "自定身高", onClick: {
                                guard let ht = Double(heightInput) else {
                                    showHint("请输入有效身高数值", false); return
                                }
                                if ht < -1.4 || ht > 16.6 {
                                    showHint("超出范围(-1.4~16.6)", false); return
                                }
                                runPermApi(perm: "height", loading: "自定身高") {
                                    APIClient.setHeight(uid: currentAccount()!.id, s: 0.0, h: (7.6 - ht) / 3.0)
                                }
                            })
                        }
                        HStack(spacing: 10) {
                            GlassOutlineButton(text: "长大成人", onClick: {
                                runPermApi(perm: "height", loading: "长大成人") {
                                    APIClient.setHeight(uid: currentAccount()!.id, s: 0.2, h: 4.5)
                                }
                            })
                            GlassOutlineButton(text: "返老还童", onClick: {
                                runPermApi(perm: "height", loading: "返老还童") {
                                    APIClient.setHeight(uid: currentAccount()!.id, s: 0.0, h: -2.9333)
                                }
                            })
                        }
                    }

                    // ---------- 光翼修改 ----------
                    GlassCard(glowColor: .ambientPink) {
                        GlassCardTitle(text: "光翼修改", tint: .ambientPink)
                        HStack(spacing: 10) {
                            GlassButton(text: "变身满翼", onClick: {
                                runPermApi(perm: "wing", loading: "变身满翼") {
                                    APIClient.setWing(uid: currentAccount()!.id, type: 2)
                                }
                            }, brush: LinearGradient(colors: [.ambientPink, Color(hex: 0xFF9A4DFF)], startPoint: .leading, endPoint: .trailing))
                            GlassOutlineButton(text: "变身无翼", onClick: {
                                runPermApi(perm: "wing", loading: "变身无翼") {
                                    APIClient.setWing(uid: currentAccount()!.id, type: 1)
                                }
                            })
                            GlassOutlineButton(text: "恢复光翼", onClick: {
                                runPermApi(perm: "wing", loading: "恢复光翼") {
                                    APIClient.setWing(uid: currentAccount()!.id, type: 3)
                                }
                            })
                        }
                    }

                    CurrentAccountChip(currentId: currentId, accounts: accounts)

                    Text("操作完成后重新登录游戏生效")
                        .font(.system(size: 12))
                        .foregroundColor(.textFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }

            if busy { BusyOverlay(action: busyAction) }

            if hintVisible, let hint = hint {
                VStack {
                    Spacer()
                    GlassFloatingHint(message: hint.0, success: hint.1)
                        .onTapGesture { hintVisible = false }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                }
            }
        }
        .task(id: accountId) {
            guard let aid = AuthStore.shared.user?.id else { return }
            guard let ids = try? await LicenseApi.getGameIds(accountId: String(aid)) else { return }
            let local = Set(AccountStore.shared.accounts.map { $0.id })
            var changed = false
            for id in ids where !local.contains(id) {
                AccountStore.shared.addAccount(id: id, note: "")
                changed = true
            }
            if changed { refreshAccounts() }
        }
    }

    // MARK: 内部逻辑(对齐 Android)
    func refreshAccounts() {
        accounts = AccountStore.shared.accounts
        currentId = AccountStore.shared.currentId
    }

    func currentAccount() -> Account? {
        accounts.first { $0.id == currentId }
    }

    func showHint(_ msg: String, _ success: Bool = true) {
        hint = (msg, success)
        hintVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            hintVisible = false
        }
    }

    func addAccount() {
        let aid = idInput.trimmingCharacters(in: .whitespaces)
        let note = noteInput.trimmingCharacters(in: .whitespaces)
        guard !aid.isEmpty else { showHint("游戏ID不能为空", false); return }
        let nsRange = NSRange(aid.startIndex..<aid.endIndex, in: aid)
        guard UUID_REGEX.firstMatch(in: aid, range: nsRange) != nil else {
            showHint("ID格式错误!需为 UUID 格式", false); return
        }
        guard !accounts.contains(where: { $0.id == aid }) else { showHint("该ID已存在", false); return }

        guard let accId = AuthStore.shared.user?.id.description, !accId.isEmpty else {
            showHint("登录状态异常,请重新登录", false); return
        }
        Task {
            do {
                _ = try await LicenseApi.registerGameId(accountId: accId, gameId: aid)
                let ok = AccountStore.shared.addAccount(id: aid, note: note)
                idInput = ""
                noteInput = ""
                refreshAccounts()
                showHint(ok ? "账号已添加并选中" : "该ID已添加过,已选中")
            } catch {
                let msg = error.localizedDescription
                if msg.contains("已添加过") {
                    AccountStore.shared.addAccount(id: aid, note: note)
                    idInput = ""
                    noteInput = ""
                    refreshAccounts()
                    showHint("该ID已登记过,已恢复显示", false)
                } else {
                    showHint(msg, false)
                }
            }
        }
    }

    /// 带权限校验的接口调用
    func runPermApi(perm: String, loading: String, _ block: @escaping () async throws -> String) {
        guard !busy else { return }
        guard let acc = currentAccount() else {
            showHint("请先在账号管理中添加并选中一个账号", success: false); return
        }
        guard let aid = AuthStore.shared.user?.id.description, !aid.isEmpty else {
            showHint("登录状态异常,请重新登录", success: false); return
        }
        busy = true
        busyAction = "校验权限"
        Task {
            defer { busy = false; busyAction = "" }
            do {
                let state = try? await LicenseApi.checkPermission(accountId: aid)
                let has = (perm == "height") ? (state?.height == true) : (state?.wing == true)
                if !has {
                    showHint(perm == "height"
                             ? "身高权限未激活,请到「我的」页输入身高卡密激活"
                             : "光翼权限未激活,请到「我的」页输入光翼卡密激活", success: false)
                    return
                }
                let used = (try? await LicenseApi.checkGameUsage(accountId: aid)) ?? []
                if !used.contains(acc.id) && used.count >= 2 {
                    showHint("已达账号使用上限(2个),无法使用新账号", success: false)
                    return
                }
                let result = try await block()
                if !result.contains("失败") && !result.contains("错误") {
                    try? await LicenseApi.recordGameUsage(accountId: aid, gameId: acc.id)
                }
                showHint(result)
            } catch {
                showHint("请求失败:\(error.localizedDescription)", success: false)
            }
        }
    }
}

// MARK: - 顶栏
private struct AppHeader: View {
    var body: some View {
        Text("进阶助手")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFF9FE8FF)]))
            .shadow(color: .ambientViolet.opacity(0.6), radius: 12, y: 3)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 账号列表
private struct AccountList: View {
    let accounts: [Account]
    let currentId: String?
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        if accounts.isEmpty {
            Text("暂无保存账号,添加后自动选中")
                .font(.system(size: 12))
                .foregroundColor(.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 8) {
                ForEach(accounts) { acc in
                    let selected = acc.id == currentId
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selected
                                  ? LinearGradient(colors: [.accentStart, .accentEnd])
                                  : LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.08)]))
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(acc.id)
                                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                .foregroundColor(selected ? .white : .textSecondary)
                                .lineLimit(1)
                            Text(acc.note.isEmpty ? "无备注" : acc.note)
                                .font(.system(size: 11))
                                .foregroundColor(.textFaint)
                                .lineLimit(1)
                        }
                        if selected {
                            Text("已选")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.ambientCyan)
                            Spacer().frame(width: 8)
                        }
                        Button(action: { onDelete(acc.id) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                                .foregroundColor(.danger)
                                .frame(width: 26, height: 26)
                                .background(Color.danger.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                        selected
                            ? LinearGradient(colors: [.accentStart, .accentEnd])
                            : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.03)]),
                        lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture { onSelect(acc.id) }
                }
            }
        }
    }
}

// MARK: - 当前账号状态胶囊
private struct CurrentAccountChip: View {
    let currentId: String?
    let accounts: [Account]
    var body: some View {
        let acc = accounts.first { $0.id == currentId }
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(.ambientGold)
            Text(acc != nil ? "当前操作账号:\(acc!.id)" : "当前未选中账号")
                .font(.system(size: 12))
                .foregroundColor(acc != nil ? .textPrimary : .textFaint)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 50).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 50))
    }
}

// MARK: - 忙碌遮罩
private struct BusyOverlay: View {
    let action: String
    @State private var angle: Double = 0
    var body: some View {
        ZStack {
            Color(hex: 0x55101830).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(angle))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            angle = 360
                        }
                    }
                Text("正在\(action)…")
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
            }
        }
    }
}
