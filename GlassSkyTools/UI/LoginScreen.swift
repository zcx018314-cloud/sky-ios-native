import SwiftUI
import Foundation

/// 登录/注册页(对齐 Android LoginScreen.kt)
struct LoginScreen: View {
    var onSuccess: () -> Void

    @State private var isRegister = false
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var errorMsg: String? = nil

    var body: some View {
        ZStack {
            GlassBackground()
            VStack(spacing: 0) {
                Spacer()
                Text("进阶助手")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFF9FE8FF)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .ambientViolet.opacity(0.6), radius: 12, y: 3)
                Text(isRegister ? "注册新账号" : "登录账号")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.top, 4)
                    .padding(.bottom, 28)

                GlassCard(glowColor: .ambientCyan) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.textFaint)
                            .frame(width: 18, height: 18)
                        GlassTextField(value: username,
                                       onValueChange: { username = $0 },
                                       placeholder: "用户名(2-16位,支持中文)")
                    }
                    Spacer().frame(height: 10)
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.textFaint)
                            .frame(width: 18, height: 18)
                        GlassTextField(value: password,
                                       onValueChange: { password = $0 },
                                       placeholder: "密码(至少6位)")
                    }
                    if isRegister {
                        Spacer().frame(height: 10)
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.textFaint)
                                .frame(width: 18, height: 18)
                            GlassTextField(value: confirm,
                                           onValueChange: { confirm = $0 },
                                           placeholder: "确认密码")
                        }
                    }
                    Spacer().frame(height: 14)
                    GlassButton(text: isRegister ? "注册并登录" : "登录",
                                onClick: { doAuth() },
                                enabled: !busy,
                                loading: busy)
                    if let errorMsg = errorMsg {
                        Spacer().frame(height: 10)
                        Text(errorMsg)
                            .font(.system(size: 12))
                            .foregroundColor(.danger)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Spacer().frame(height: 18)
                Text(isRegister ? "已有账号?去登录" : "没有账号?去注册")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onTapGesture { isRegister.toggle(); errorMsg = nil }
                Spacer()
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func doAuth() {
        let u = username.trimmingCharacters(in: .whitespaces)
        let p = password
        guard !u.isEmpty, !p.isEmpty else {
            errorMsg = "请输入用户名和密码"
            return
        }
        if isRegister {
            guard p.count >= 6 else { errorMsg = "密码至少 6 位"; return }
            guard p == confirm else { errorMsg = "两次输入的密码不一致"; return }
        }
        busy = true
        errorMsg = nil
        Task {
            do {
                let auth = isRegister
                    ? try await AuthApi.register(username: u, password: p)
                    : try await AuthApi.login(username: u, password: p)
                AuthStore.shared.save(token: auth.token, user: auth.user)
                await MainActor.run { onSuccess() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
            await MainActor.run { busy = false }
        }
    }
}
