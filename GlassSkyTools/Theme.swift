import SwiftUI

// MARK: - 颜色 Hex 初始化(对齐 Android Color(0xAARRGGBB))
extension Color {
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255.0
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // ---------- 环境光斑色 ----------
    static let ambientViolet = Color(hex: 0xFF6D5DF6)
    static let ambientCyan   = Color(hex: 0xFF00C2D1)
    static let ambientPink   = Color(hex: 0xFFF065A8)
    static let ambientGold   = Color(hex: 0xFFFFC46B)

    // ---------- 背景 ----------
    static let deepBgStart = Color(hex: 0xFF0A0E1C)
    static let deepBgMid   = Color(hex: 0xFF141B3A)
    static let deepBgEnd   = Color(hex: 0xFF1B1033)

    // ---------- 玻璃 ----------
    static let glassFillTop    = Color.white.opacity(0.16)
    static let glassFillBottom = Color.white.opacity(0.04)
    static let glassBorderLight = Color.white.opacity(0.42)
    static let glassBorderDark  = Color.white.opacity(0.05)

    // ---------- 文字 ----------
    static let textPrimary   = Color(hex: 0xFFF2F4FF)
    static let textSecondary = Color(hex: 0xFFB8C0E0)
    static let textFaint     = Color(hex: 0xFF7A84AC)

    // ---------- 渐变主色 ----------
    static let accentStart = Color(hex: 0xFF7C5CFF)
    static let accentEnd   = Color(hex: 0xFF00B7D4)
    static let pinkAccent = Color(hex: 0xFFF065A8)

    // ---------- 危险 ----------
    static let danger = Color(hex: 0xFFFF6B7A)

    // ---------- 头像调色板(按 seed 哈希取色) ----------
    static let avatarPalettes: [[Color]] = [
        [Color(hex: 0xFF7C5CFF), Color(hex: 0xFF00B7D4)],   // 紫青
        [Color(hex: 0xFFF065A8), Color(hex: 0xFF9A4DFF)],   // 粉紫
        [Color(hex: 0xFFFFB35C), Color(hex: 0xFFFF5C8A)],   // 橙粉
        [Color(hex: 0xFF00C2A8), Color(hex: 0xFF2E86FF)],   // 青蓝
        [Color(hex: 0xFFFF5C7A), Color(hex: 0xFFFF9A5C)],   // 红橙
        [Color(hex: 0xFF36D1DC), Color(hex: 0xFF5B86E5)],   // 湖蓝
        [Color(hex: 0xFFF7971E), Color(hex: 0xFFFFD200)],   // 金黄
        [Color(hex: 0xFFB06AB3), Color(hex: 0xFF4568DC)],   // 紫蓝
    ]
}
