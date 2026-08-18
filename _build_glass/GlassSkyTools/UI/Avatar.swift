import SwiftUI

/// 头像渐变调色板(按 seed 哈希取色)
func avatarColors(_ seed: String) -> [Color] {
    let h = abs(seed.hashValue) % Color.avatarPalettes.count
    return Color.avatarPalettes[h]
}

func avatarLetter(_ name: String) -> String {
    if let first = name.first {
        return String(first).uppercased()
    }
    return "?"
}

/// 字母渐变头像(所有人一致的展示方式)
struct LetterAvatar: View {
    let name: String
    let seed: String
    let size: CGFloat
    var textSize: CGFloat = 18

    var body: some View {
        let colors = avatarColors(seed)
        Text(avatarLetter(name))
            .font(.system(size: textSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
            .shadow(color: colors[0], radius: 8)
    }
}

/// 远端头像:优先服务端自定义头像,加载失败/无头像时回退字母渐变
struct RemoteAvatar: View {
    let id: Int
    let name: String
    let seed: String
    let size: CGFloat
    var version: Int = 0

    var body: some View {
        let url = URL(string: "http://120.48.161.149:18700/avatars/\(id).png?v=\(version)")
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                LetterAvatar(name: name, seed: seed, size: size)
            default:
                Color.white.opacity(0.1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// 个人页头像:优先服务端自定义头像(跨设备可用),加载失败回退字母渐变
struct ProfileAvatar: View {
    let uid: Int
    let name: String
    let seed: String
    let size: CGFloat
    var version: Int = 0
    var onClick: (() -> Void)? = nil

    var body: some View {
        RemoteAvatar(id: uid, name: name, seed: seed, size: size, version: version)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .onTapGesture { onClick?() }
    }
}

/// 聊天页头像
struct ChatAvatar: View {
    let fromId: Int
    let name: String
    let seed: String
    let size: CGFloat
    var version: Int = 0

    var body: some View {
        RemoteAvatar(id: fromId, name: name, seed: seed, size: size, version: version)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}
