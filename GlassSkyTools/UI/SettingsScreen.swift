import SwiftUI
import UIKit

/// 「我的」设置页(对齐 Android SettingsScreen.kt)
struct SettingsScreen: View {
    var onLoggedOut: () -> Void

    @State private var user = AuthStore.shared.user
    @State private var hint: String? = nil
    @State private var hintOk = true

    @State private var editingName = false
    @State private var nameDraft = ""

    @State private var editingPwd = false
    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var newPwd2 = ""

    @State private var permState: PermissionState? = nil
    @State private var heightCode = ""
    @State private var wingCode = ""
    @State private var permBusy = false

    @State private var avatarVersion = 0

    @State private var showPicker = false

    private var userId: String? { AuthStore.shared.user?.id.description }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ---------- 头像 + 用户名 ----------
                    GlassCard(glowColor: .ambientViolet) {
                        VStack(spacing: 0) {
                            ProfileAvatar(
                                uid: user?.id ?? 0,
                                name: user?.nickname ?? user?.username ?? "?",
                                seed: user?.avatarSeed ?? "",
                                size: 84,
                                version: avatarVersion,
                                onClick: { showPicker = true }
                            )
                            Spacer().frame(height: 12)
                            Text(user?.nickname ?? "")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFB9C4FF)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .ambientViolet.opacity(0.4), radius: 8, y: 2)
                            Text("@\(user?.username ?? "")")
                                .font(.system(size: 12))
                                .foregroundColor(.textFaint)
                                .padding(.top, 2)
                            Spacer().frame(height: 8)
                            Text("点击头像更换头像,自定义头像会同步给所有聊友")
                                .font(.system(size: 10))
                                .foregroundColor(.textFaint)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // ---------- 账号设置 ----------
                    GlassCard(glowColor: .ambientCyan) {
                        GlassCardTitle(text: "账号设置", tint: .ambientCyan)
                        settingRow(icon: "pencil", title: "昵称", value: user?.nickname ?? "") {
                            nameDraft = user?.nickname ?? ""
                            editingName = true
                        }
                        settingRow(icon: "lock", title: "密码", value: "修改登录密码") {
                            oldPwd = ""; newPwd = ""; newPwd2 = ""
                            editingPwd = true
                        }
                    }

                    // ---------- 界面模式 ----------
                    GlassCard(glowColor: .ambientCyan) {
                        GlassCardTitle(text: "界面模式", tint: .ambientCyan)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前模式").font(.system(size: 11)).foregroundColor(.textFaint)
                                Text(ThemeMode.shared.isDay ? "白天模式(暖色)" : "夜晚模式(深色)")
                                    .font(.system(size: 14)).foregroundColor(.textPrimary)
                            }
                            Spacer()
                            Text("切换 >").font(.system(size: 12)).foregroundColor(.ambientCyan)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture { ThemeMode.shared.toggle() }
                        Text("点击行可立即切换;选择会自动保存,重启后保持")
                            .font(.system(size: 10))
                            .foregroundColor(.textFaint)
                            .padding(.top, 10)
                    }

                    // ---------- 我的权限 ----------
                    GlassCard(glowColor: .ambientGold) {
                        GlassCardTitle(text: "我的权限", tint: .ambientGold)
                        Text("权限卡密绑定当前登录账号,换设备登录同账号权限依然有效(永久)")
                            .font(.system(size: 10))
                            .foregroundColor(.textFaint)
                            .padding(.bottom, 4)
                        PermissionRow(
                            title: "身高权限",
                            loading: permState == nil,
                            activated: permState?.height == true,
                            code: heightCode,
                            onCode: { heightCode = $0 },
                            onActivate: {
                                activate(type: "height", code: heightCode)
                            }
                        )
                        PermissionRow(
                            title: "光翼权限",
                            loading: permState == nil,
                            activated: permState?.wing == true,
                            code: wingCode,
                            onCode: { wingCode = $0 },
                            onActivate: {
                                activate(type: "wing", code: wingCode)
                            }
                        )
                    }

                    // ---------- 退出登录 ----------
                    GlassOutlineButton(
                        text: "退出登录",
                        onClick: {
                            AuthStore.shared.clear()
                            onLoggedOut()
                        },
                        brush: LinearGradient(colors: [.danger.opacity(0.25), .danger.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }

            // ---------- 改昵称浮层 ----------
            if editingName {
                Color(hex: 0xE6101830).ignoresSafeArea()
                    .onTapGesture { editingName = false }
                GlassCard(glowColor: .ambientCyan) {
                    GlassCardTitle(text: "修改昵称", tint: .ambientCyan)
                    GlassTextField(value: nameDraft, onValueChange: { nameDraft = $0 }, placeholder: "输入新昵称(≤16字)")
                    HStack(spacing: 10) {
                        GlassOutlineButton(text: "取消", onClick: { editingName = false })
                        GlassButton(text: "确定", onClick: {
                            let n = String(nameDraft.trimmingCharacters(in: .whitespaces).prefix(16))
                            guard !n.isEmpty else { return }
                            Task {
                                do {
                                    let updated = try await AuthApi.updateProfile(
                                        token: AuthStore.shared.token ?? "",
                                        nickname: n,
                                        seed: user?.avatarSeed ?? "")
                                    AuthStore.shared.save(token: AuthStore.shared.token ?? "", user: updated)
                                    user = updated
                                    Task { @MainActor in show("昵称已更新"); editingName = false }
                                } catch {
                                    Task { @MainActor in show("更新失败:\(error.localizedDescription)", false) }
                                }
                            }
                        })
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            }

            // ---------- 改密码浮层 ----------
            if editingPwd {
                Color(hex: 0xE6101830).ignoresSafeArea()
                    .onTapGesture { editingPwd = false }
                GlassCard(glowColor: .ambientGold) {
                    GlassCardTitle(text: "修改密码", tint: .ambientGold)
                    GlassTextField(value: oldPwd, onValueChange: { oldPwd = $0 }, placeholder: "原密码")
                    GlassTextField(value: newPwd, onValueChange: { newPwd = $0 }, placeholder: "新密码(至少6位)")
                    GlassTextField(value: newPwd2, onValueChange: { newPwd2 = $0 }, placeholder: "确认新密码")
                    HStack(spacing: 10) {
                        GlassOutlineButton(text: "取消", onClick: { editingPwd = false })
                        GlassButton(text: "确定", onClick: {
                            guard newPwd.count >= 6 else { show("新密码至少 6 位", false); return }
                            guard newPwd == newPwd2 else { show("两次密码不一致", false); return }
                            Task {
                                do {
                                    try await AuthApi.changePassword(
                                        token: AuthStore.shared.token ?? "",
                                        old: oldPwd, new: newPwd)
                                    Task { @MainActor in show("密码已修改"); editingPwd = false }
                                } catch {
                                    Task { @MainActor in show("修改失败:\(error.localizedDescription)", false) }
                                }
                            }
                        })
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            }
            // ---------- 底部浮动提示(显眼,自动消失) ----------
            if let hint = hint {
                VStack {
                    Spacer()
                    GlassFloatingHint(message: hint, success: hintOk)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.25), value: hint)
            }
        }
        .task(id: userId) {
            guard let aid = userId else { return }
            permState = try? await LicenseApi.checkPermission(accountId: aid)
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { handleImage($0) }
        }
    }

    // MARK: 内部方法
    func show(_ msg: String, _ ok: Bool = true) {
        hint = msg
        hintOk = ok
        // 2.6 秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            if hint == msg { hint = nil }
        }
    }

    func settingRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(.textFaint)
                .frame(width: 18, height: 18)
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11)).foregroundColor(.textFaint)
                Text(value).font(.system(size: 14)).foregroundColor(.textPrimary)
            }
            Spacer()
            Text("修改 >").font(.system(size: 12)).foregroundColor(.ambientCyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: action)
    }

    func activate(type: String, code: String) {
        guard !permBusy else { return }
        guard let aid = userId else {
            show("登录状态异常,请重新登录", false); return
        }
        permBusy = true
        Task {
            defer { permBusy = false }
            do {
                let msg = try await LicenseApi.verifyPermission(
                    code: code.trimmingCharacters(in: .whitespaces),
                    accountId: aid,
                    type: type)
                Task { @MainActor in
                    show(msg)
                    if type == "height" { heightCode = "" } else { wingCode = "" }
                    permState = try? await LicenseApi.checkPermission(accountId: aid)
                }
            } catch {
                Task { @MainActor in show(error.localizedDescription, false) }
            }
        }
    }

    func handleImage(_ img: UIImage) {
        show("正在上传头像…")
        Task {
            do {
                guard let png = resizeAvatar(img) else { throw APIError(msg: "图片压缩失败") }
                _ = try await AuthApi.uploadAvatar(token: AuthStore.shared.token ?? "", pngData: png)
                // 清缓存,强制 AsyncImage 重新拉取新头像
                URLCache.shared.removeAllCachedResponses()
                Task { @MainActor in
                    avatarVersion += 1
                    show("头像已更新,聊天中所有人可见")
                }
            } catch {
                Task { @MainActor in show("上传失败:\(error.localizedDescription)", false) }
            }
        }
    }

    /// 压缩头像到最长边 512px:
    /// 服务器 /api/upload_avatar 限制请求体最大 1MB(1048576),
    /// 服务器 /api/upload_avatar 限制请求体最大 1MB(1048576),base64 膨胀 ~33%。
    /// 用 JPEG 0.85 而非 PNG:人眼无感但文件小 5-10 倍,稳过限制。
    /// 服务器按 base64 解码后存为 /avatars/{id}.png 后缀,数据是 JPEG 也无妨——
    /// iOS AsyncImage 内部按数据嗅探解码,后缀不影响显示。
    func resizeAvatar(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 512
        let w = image.size.width
        let h = image.size.height
        let scale = min(1.0, maxSide / max(w, h))
        let newW = max(1, Int(w * scale))
        let newH = max(1, Int(h * scale))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newW, height: newH))
        let resized = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: newW, height: newH))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - 单条权限行
private struct PermissionRow: View {
    let title: String
    let loading: Bool
    let activated: Bool
    let code: String
    let onCode: (String) -> Void
    let onActivate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.textPrimary)
                Spacer()
                Text(loading ? "加载中…" : (activated ? "已激活 · 永久" : "未激活"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(loading ? .textFaint : (activated ? .ambientCyan : .danger))
            }
            if !loading && !activated {
                GlassTextField(value: code, onValueChange: onCode, placeholder: "输入\(title)卡密")
                GlassOutlineButton(text: "激活", onClick: onActivate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 相册选图(UIImagePickerController 包装)
private struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onPick(img)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
