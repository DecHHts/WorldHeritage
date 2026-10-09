import SwiftUI

/// 足迹的订阅部分：年度回顾、徽章、可分享海报
struct FootprintProView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var journal: JournalStore
    @EnvironmentObject private var settings: AppSettings

    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var share: ShareItem? = nil

    private let store = DataStore.shared
    private static let milestones = [1, 5, 10, 25, 50, 100, 250]

    private var years: [Int] {
        let ys = journal.years(visited: favorites.visited)
        return ys.isEmpty ? [Calendar.current.component(.year, from: Date())] : ys
    }

    var body: some View {
        List {
            Section {
                Picker(T("年份"), selection: $year) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                let list = journal.sites(inYear: year, visited: favorites.visited)
                if list.isEmpty {
                    Text(T("这一年还没有打卡记录"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    reviewCard(list)
                        .listRowInsets(EdgeInsets())
                    ForEach(list) { site in
                        NavigationLink(value: site) {
                            SiteRow(site: site, thumbnail: true)
                        }
                    }
                }
            } header: {
                Text(T("年度回顾"))
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 18) {
                    ForEach(store.regions, id: \.self) { r in
                        let total = store.sites.filter { $0.r.contains(r) }.count
                        let done = favorites.visitedSites.filter { $0.r.contains(r) }.count
                        BadgeView(image: BadgeView.regionImage(r), title: T(r), done: done, total: total, color: settings.theme.accent)
                    }
                    ForEach(HeritageCategory.allCases) { c in
                        let total = store.sites.filter { $0.category == c }.count
                        let done = favorites.visitedSites.filter { $0.category == c }.count
                        BadgeView(image: BadgeView.categoryImage(c), title: c.title, done: done, total: total, color: c.color)
                    }
                    ForEach(FootprintProView.milestones, id: \.self) { m in
                        BadgeView(image: BadgeView.milestoneImage(m), title: T("到访 %d 项", m),
                                  done: min(favorites.visited.count, m), total: m,
                                  color: BadgeView.milestoneColor(m), number: m)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(T("徽章"))
            }

            Section {
                Button {
                    makePoster()
                } label: {
                    Label(T("生成足迹海报并分享"), systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text(T("海报包含你的足迹地图和到访统计，不含位置轨迹。"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("回顾与徽章"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !years.contains(year), let first = years.first { year = first }
        }
        .sheet(item: $share) { item in
            ActivityView(items: item.items)
        }
    }

    private func reviewCard(_ list: [Site]) -> some View {
        var countries = Set<String>()
        for s in list { for c in s.cc { countries.insert(c) } }
        let cultural = list.filter { $0.category == .cultural }.count
        let natural = list.filter { $0.category == .natural }.count
        let mixed = list.filter { $0.category == .mixed }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text(T("%@ 年，你到访了", String(year)))
                .font(.subheadline)
                .opacity(0.9)
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                bigStat(list.count, T("项遗产"))
                bigStat(countries.count, T("个国家"))
            }
            HStack(spacing: 8) {
                if cultural > 0 { pill("building.columns.fill", cultural) }
                if natural > 0 { pill("leaf.fill", natural) }
                if mixed > 0 { pill("mountain.2.fill", mixed) }
            }
            if let first = list.first, let last = list.last, first.id != last.id {
                Text(T("从 %@ 到 %@", first.name, last.name))
                    .font(.caption)
                    .opacity(0.85)
                    .lineLimit(2)
            }
        }
        .foregroundColor(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.20, green: 0.60, blue: 0.62),
                                    Color(red: 0.25, green: 0.36, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private func bigStat(_ value: Int, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)").font(.system(size: 34, weight: .bold, design: .rounded))
            Text(title).font(.subheadline)
        }
    }

    private func pill(_ symbol: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2)
            Text("\(value)").font(.caption.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }

    @MainActor
    private func makePoster() {
        let poster = PosterView(wish: favorites.wishSites, visited: favorites.visitedSites,
                                total: store.sites.count, countries: favorites.visitedCountryCount)
            .frame(width: 360)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let image = renderer.uiImage {
            share = ShareItem(items: [image])
        }
    }
}

struct BadgeView: View {
    /// 徽章图片名
    let image: String
    let title: String
    let done: Int
    let total: Int
    let color: Color
    /// 叠在徽章中央的数字（里程碑徽章用）
    var number: Int? = nil

    var body: some View {
        let progress = total > 0 ? Double(done) / Double(total) : 0
        let earned = number == nil ? done > 0 : done >= total
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .saturation(earned ? 1 : 0)
                    .opacity(earned ? 1 : 0.45)
                if let number = number {
                    Text("\(number)")
                        .font(.system(size: number >= 100 ? 15 : 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(earned ? 1 : 0.7)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                }
            }
            .frame(width: 72, height: 72)
            Text(title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("\(min(done, total))/\(total)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    static func regionImage(_ region: String) -> String {
        switch region {
        case "亚洲和太平洋": return "badge_asia"
        case "欧洲和北美": return "badge_europe"
        case "非洲": return "badge_africa"
        case "阿拉伯国家": return "badge_arab"
        default: return "badge_latin"
        }
    }

    static func categoryImage(_ c: HeritageCategory) -> String {
        switch c {
        case .cultural: return "badge_cultural"
        case .natural: return "badge_natural"
        case .mixed: return "badge_mixed"
        }
    }

    static func milestoneImage(_ m: Int) -> String {
        m < 10 ? "badge_bronze" : (m < 50 ? "badge_silver" : "badge_gold")
    }

    static func milestoneColor(_ m: Int) -> Color {
        m < 10 ? Color(red: 0.72, green: 0.47, blue: 0.28)
            : (m < 50 ? Color(red: 0.55, green: 0.60, blue: 0.66) : Color(red: 0.85, green: 0.64, blue: 0.18))
    }
}

/// 分享用的足迹海报（固定浅色配色，离屏渲染）
struct PosterView: View {
    let wish: [Site]
    let visited: [Site]
    let total: Int
    let countries: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(T("我的世界遗产足迹"))
                    .font(.system(size: 22, weight: .bold))
                Text(dateText)
                    .font(.system(size: 12))
                    .opacity(0.75)
            }
            FootprintWorldView(wish: wish, visited: visited)
                .padding(10)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack(spacing: 0) {
                stat("\(visited.count)", T("去过"))
                stat("\(countries)", T("国家"))
                stat("\(wish.count)", T("想去"))
                stat(String(format: "%.1f%%", total > 0 ? Double(visited.count) / Double(total) * 100 : 0), T("完成度"))
            }
            Text(T("世遗漫游 · UNESCO 世界遗产名录"))
                .font(.system(size: 11))
                .opacity(0.7)
        }
        .foregroundColor(.white)
        .padding(22)
        .background(Theme.current.hero)
        .environment(\.colorScheme, .light)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = L10n.lang.locale
        f.dateStyle = .long
        return f.string(from: Date())
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(title).font(.system(size: 11)).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
