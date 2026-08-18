import SwiftUI

// ============================================================
// 液态玻璃(Liquid Glass)组件库
// 视觉语言:深色环境光斑 + 半透明玻璃板 + 渐变高光描边 + 顶部折射光
// ============================================================

let glassShape = RoundedRectangle(cornerRadius: 28)

/// 按压回弹样式
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 全屏液态玻璃背景:深色渐变 + 背景图 + 顶部氛围光
struct GlassBackground: View {
    @EnvironmentObject private var themeMode: ThemeMode
    var body: some View {
        GeometryReader { geo in
            let isDay = themeMode.isDay
            ZStack {
                Image(isDay ? "app_bg_day" : "app_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                // 遮罩(保证玻璃 UI 可读性)
                LinearGradient(
                    colors: isDay
                        ? [Color(hex: 0x55000000), Color(hex: 0x44000000), Color(hex: 0x66000000)]
                        : [Color(hex: 0xAA0E1733), Color(hex: 0xCC0B1733), Color(hex: 0xAA0E1733)]
                )
                .frame(width: geo.size.width, height: geo.size.height)
                // 顶部氛围光
                VStack {
                    LinearGradient(
                        colors: isDay
                            ? [Color(hex: 0xFFFFE8C8).opacity(0.22), Color.clear]
                            : [Color.ambientViolet.opacity(0.18), Color.clear]
                    )
                    .frame(height: 280)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// 玻璃卡片:半透明填充 + 渐变描边 + 外发光 + 顶部折射高光
struct GlassCard<Content: View>: View {
    @EnvironmentObject private var themeMode: ThemeMode
    let glowColor: Color
    let content: Content

    init(glowColor: Color = .ambientViolet, @ViewBuilder content: () -> Content) {
        self.glowColor = glowColor
        self.content = content()
    }

    var body: some View {
        let isDay = themeMode.isDay
        let fillTop = isDay ? Color(hex: 0x55001A2C) : Color.glassFillTop
        let fillBottom = isDay ? Color(hex: 0x66001A2C) : Color.glassFillBottom
        let borderLight = isDay ? Color(hex: 0xFF7AA8C8).opacity(0.55) : Color.glassBorderLight
        let borderDark = isDay ? Color(hex: 0xFF5A7898).opacity(0.30) : Color.glassBorderDark.opacity(0.10)
        let refLight = isDay ? Color(hex: 0xFFB9E0FF).opacity(0.7) : Color.white.opacity(0.55)

        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                content
            }
            .padding(20)
            .background(LinearGradient(colors: [fillTop, fillBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(glassShape.stroke(LinearGradient(colors: [borderLight, borderDark], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .clipShape(glassShape)
            .shadow(color: glowColor.opacity(isDay ? 0.35 : 0.55), radius: 18)
            // 顶部折射光条
            Capsule()
                .fill(LinearGradient(colors: [Color.clear, refLight, Color.clear]))
                .frame(width: nil, height: 2)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .center)
                .mask(glassShape)
        }
    }
}

/// 卡片标题:渐变小圆点 + 渐变文字
struct GlassCardTitle: View {
    let text: String
    var tint: Color = .textPrimary
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [.ambientViolet, .ambientCyan]))
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFB9C4FF)]))
                .shadow(color: .ambientViolet.opacity(0.45), radius: 12, y: 2)
        }
    }
}

/// 玻璃输入框
struct GlassTextField: View {
    let value: String
    let onValueChange: (String) -> Void
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: Binding(get: { value }, set: { onValueChange($0) }),
                  prompt: Text(placeholder).foregroundColor(.textFaint))
            .foregroundColor(.textPrimary)
            .font(.system(size: 15))
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(focused ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                focused
                    ? LinearGradient(colors: [.accentStart.opacity(0.9), .accentEnd.opacity(0.9)])
                    : LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.05)]),
                lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .focused($focused)
            .keyboardType(keyboardType)
    }
}

/// 玻璃主按钮:渐变胶囊,按压回弹
struct GlassButton: View {
    let text: String
    let onClick: () -> Void
    var enabled: Bool = true
    var brush: LinearGradient = LinearGradient(colors: [.accentStart, .accentEnd], startPoint: .leading, endPoint: .trailing)
    var loading: Bool = false

    var body: some View {
        Button(action: onClick) {
            Text(loading ? "处理中…" : text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(brush)
                .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)]), lineWidth: 1))
                .clipShape(Capsule())
                .shadow(color: .accentStart, radius: 10)
                .opacity(enabled ? 1 : 0.45)
        }
        .disabled(!enabled || loading)
        .buttonStyle(PressableStyle())
    }
}

/// 玻璃次级按钮:描边玻璃风格
struct GlassOutlineButton: View {
    let text: String
    let onClick: () -> Void
    var enabled: Bool = true
    var brush: LinearGradient = LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.06)])

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(enabled ? .textPrimary : .textFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(brush)
                .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0.08)]), lineWidth: 1))
                .clipShape(Capsule())
        }
        .disabled(!enabled)
        .buttonStyle(PressableStyle())
    }
}

/// 玻璃悬浮提示(替代 Alert/Toast 的结果反馈)
struct GlassFloatingHint: View {
    let message: String
    let success: Bool
    var body: some View {
        let color = success ? Color.ambientCyan : Color.danger
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(color)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(hex: 0xE6141A33))
        .overlay(Capsule().stroke(LinearGradient(colors: [color.opacity(0.6), .white.opacity(0.15)]), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: color, radius: 16)
    }
}

/// 液态玻璃底部导航栏
struct GlassBottomNav: View {
    @EnvironmentObject private var themeMode: ThemeMode
    let selected: Int
    let onSelect: (Int) -> Void
    var body: some View {
        let isDay = themeMode.isDay
        HStack(spacing: 10) {
            NavItem(icon: "wand.and.stars", label: "工具", selected: selected == 0, onClick: { onSelect(0) })
            NavItem(icon: "bubble.left", label: "聊天", selected: selected == 1, onClick: { onSelect(1) })
            NavItem(icon: "person", label: "我的", selected: selected == 2, onClick: { onSelect(2) })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isDay ? Color(hex: 0xE5001A2C) : Color(hex: 0xCC101830))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(
            isDay
                ? LinearGradient(colors: [Color(hex: 0xFF7AA8C8).opacity(0.55), Color(hex: 0xFF5A7898).opacity(0.30)])
                : LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.06)]),
            lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

struct NavItem: View {
    let icon: String
    let label: String
    let selected: Bool
    let onClick: () -> Void
    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(label)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
            }
            .foregroundColor(selected ? .white : .textFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected
                        ? LinearGradient(colors: [.accentStart.opacity(0.85), .accentEnd.opacity(0.85)])
                        : LinearGradient(colors: [.clear, .clear]))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                selected
                    ? LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)])
                    : LinearGradient(colors: [.clear, .clear]),
                lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableStyle())
    }
}
