import SwiftUI

/// 配色主题。默认主题免费，其余为订阅功能
struct Theme: Identifiable, Equatable {
    let id: String
    /// 名称（简体中文原文，显示时查表翻译）
    let nameKey: String
    let accent: Color
    /// 进度卡、海报等大色块的渐变
    let heroA: Color
    let heroB: Color
    /// 转盘扇区的几种色调
    let wheel: [Color]
    /// 转盘外圈
    let rim: Color
    /// 指定亮 / 暗外观；nil 表示跟随系统
    let scheme: ColorScheme?
    let isPro: Bool

    var name: String { T(nameKey) }
    var hero: LinearGradient {
        LinearGradient(colors: [heroA, heroB], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool { lhs.id == rhs.id }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    static let all: [Theme] = [
        Theme(id: "ochre", nameKey: "赭石", accent: c(0.80, 0.38, 0.22),
              heroA: c(0.86, 0.45, 0.24), heroB: c(0.62, 0.24, 0.20),
              wheel: [c(0.84, 0.42, 0.24), c(0.93, 0.62, 0.32), c(0.66, 0.27, 0.20), c(0.90, 0.52, 0.28)],
              rim: c(0.36, 0.15, 0.12), scheme: nil, isPro: false),
        Theme(id: "celadon", nameKey: "青瓷", accent: c(0.13, 0.53, 0.50),
              heroA: c(0.22, 0.66, 0.60), heroB: c(0.08, 0.38, 0.42),
              wheel: [c(0.16, 0.56, 0.54), c(0.38, 0.72, 0.64), c(0.09, 0.40, 0.44), c(0.26, 0.64, 0.58)],
              rim: c(0.05, 0.25, 0.28), scheme: nil, isPro: true),
        Theme(id: "indigo", nameKey: "黛蓝", accent: c(0.45, 0.54, 0.95),
              heroA: c(0.32, 0.40, 0.80), heroB: c(0.13, 0.16, 0.42),
              wheel: [c(0.30, 0.38, 0.78), c(0.46, 0.55, 0.90), c(0.18, 0.22, 0.54), c(0.38, 0.46, 0.84)],
              rim: c(0.09, 0.11, 0.30), scheme: .dark, isPro: true),
        Theme(id: "sakura", nameKey: "樱粉", accent: c(0.84, 0.36, 0.50),
              heroA: c(0.95, 0.58, 0.67), heroB: c(0.76, 0.33, 0.50),
              wheel: [c(0.88, 0.45, 0.58), c(0.96, 0.66, 0.72), c(0.74, 0.32, 0.48), c(0.92, 0.55, 0.65)],
              rim: c(0.50, 0.18, 0.30), scheme: .light, isPro: true),
        Theme(id: "inkgold", nameKey: "墨金", accent: c(0.85, 0.68, 0.34),
              heroA: c(0.24, 0.22, 0.20), heroB: c(0.08, 0.08, 0.09),
              wheel: [c(0.20, 0.19, 0.18), c(0.72, 0.56, 0.26), c(0.30, 0.28, 0.26), c(0.58, 0.45, 0.20)],
              rim: c(0.62, 0.48, 0.20), scheme: .dark, isPro: true),
        Theme(id: "pine", nameKey: "松绿", accent: c(0.20, 0.50, 0.34),
              heroA: c(0.27, 0.60, 0.42), heroB: c(0.09, 0.31, 0.25),
              wheel: [c(0.22, 0.54, 0.38), c(0.44, 0.70, 0.50), c(0.11, 0.36, 0.28), c(0.32, 0.62, 0.44)],
              rim: c(0.06, 0.22, 0.17), scheme: nil, isPro: true)
    ]

    static func find(_ id: String) -> Theme { all.first { $0.id == id } ?? all[0] }

    /// 供不在界面树里的代码读取
    static var current: Theme = all[0]
}

/// 主题选择页
struct ThemeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pro: ProStore
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(Theme.all) { theme in
                    Button {
                        if theme.isPro && !pro.isPro {
                            showPaywall = true
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) { settings.themeID = theme.id }
                        }
                    } label: {
                        card(theme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(T("主题"))
        .navigationBarTitleDisplayMode(.inline)
        .paywall($showPaywall)
    }

    private func card(_ theme: Theme) -> some View {
        let selected = settings.themeID == theme.id
        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                theme.hero
                WheelDisc(sites: [], theme: theme, placeholderSlots: 8)
                    .frame(width: 74, height: 74)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .frame(height: 94)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 6) {
                Circle().fill(theme.accent).frame(width: 12, height: 12)
                Text(theme.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
                if theme.isPro && !pro.isPro { ProBadge() }
            }
            Text(schemeText(theme))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? theme.accent : Color.clear, lineWidth: 2)
        )
    }

    private func schemeText(_ theme: Theme) -> String {
        switch theme.scheme {
        case .some(.dark): return T("深色外观")
        case .some(.light): return T("浅色外观")
        default: return T("跟随系统明暗")
        }
    }
}
