import WidgetKit
import SwiftUI
import UIKit

// MARK: - 数据

struct WSite: Codable {
    let i: Int
    let n: String
    let nt: String
    let e: String
    let nj: String
    let nk: String
    let c: String
    let y: Int
    let k: String
    let img: String
}

enum WData {
    static let defaults: UserDefaults =
        UserDefaults(suiteName: "group.com.christopher.WorldHeritage") ?? .standard

    static let sites: [WSite] = {
        guard let url = Bundle.main.url(forResource: "widget_sites", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([WSite].self, from: data) else { return [] }
        return list
    }()

    /// 与 App 内的语言设置保持一致；App 还没写入时按系统语言
    static var lang: String {
        if let saved = defaults.string(forKey: "lang") { return saved }
        let code = (Locale.preferredLanguages.first ?? "en").lowercased()
        if code.hasPrefix("zh") {
            return (code.contains("hant") || code.hasSuffix("-tw") || code.hasSuffix("-hk")) ? "hant" : "hans"
        }
        if code.hasPrefix("ja") { return "ja" }
        if code.hasPrefix("ko") { return "ko" }
        return "en"
    }

    static func t(_ hans: String, _ hant: String, _ en: String, _ ja: String, _ ko: String) -> String {
        switch lang {
        case "hans": return hans
        case "hant": return hant
        case "ja": return ja
        case "ko": return ko
        default: return en
        }
    }

    static func name(_ s: WSite) -> String {
        switch lang {
        case "hans": return s.n
        case "hant": return s.nt
        case "ja": return s.nj
        case "ko": return s.nk
        default: return s.e
        }
    }

    static func flag(_ iso: String) -> String {
        guard iso.count == 2 else { return "" }
        var out = ""
        for u in iso.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(127397 + u.value) { out.unicodeScalars.append(scalar) }
        }
        return out
    }

    /// 与 App 内 DailyPick 相同的算法
    static func today(_ date: Date) -> WSite? {
        if sites.isEmpty { return nil }
        let days = Int(floor(date.timeIntervalSince1970 / 86400
                             + Double(TimeZone.current.secondsFromGMT(for: date)) / 86400))
        return sites[abs(days &* 7919) % sites.count]
    }

    static func symbol(_ k: String) -> String {
        switch k {
        case "N": return "leaf.fill"
        case "M": return "mountain.2.fill"
        default: return "building.columns.fill"
        }
    }

    static func image(for site: WSite) async -> UIImage? {
        guard let url = URL(string: site.img),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        // 小组件内存有限，缩到长边 500 以内
        let scale = min(1, 500 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground<V: View>(_ background: V) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

private let brand = LinearGradient(colors: [Color(red: 0.86, green: 0.45, blue: 0.24),
                                            Color(red: 0.50, green: 0.20, blue: 0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: - 今日遗产

struct TodayEntry: TimelineEntry {
    let date: Date
    let site: WSite?
    let image: UIImage?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), site: WData.today(Date()), image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), site: WData.today(Date()), image: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let site = WData.today(now)
        let next = Calendar.current.startOfDay(for: now).addingTimeInterval(86400 + 60)
        Task {
            var image: UIImage? = nil
            if let site = site { image = await WData.image(for: site) }
            completion(Timeline(entries: [TodayEntry(date: now, site: site, image: image)],
                                policy: .after(next)))
        }
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let site = entry.site {
            content(site)
                .widgetURL(URL(string: "worldheritage://site/\(site.i)"))
        } else {
            Text("UNESCO")
                .widgetBackground(brand)
        }
    }

    private func content(_ site: WSite) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: WData.symbol(site.k)).font(.caption2)
                Text(WData.t("今日遗产", "今日遺產", "Today's Site", "今日の遺産", "오늘의 유산"))
                    .font(.caption2.weight(.semibold))
            }
            .opacity(0.9)
            Spacer(minLength: 0)
            Text(WData.name(site))
                .font(family == .systemSmall ? .subheadline.weight(.bold) : .headline)
                .lineLimit(family == .systemSmall ? 3 : 2)
                .minimumScaleFactor(0.8)
            Text("\(WData.flag(site.c)) \(String(site.y))")
                .font(.caption2)
                .opacity(0.9)
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(background)
    }

    @ViewBuilder
    private var background: some View {
        if let image = entry.image {
            ZStack {
                Image(uiImage: image).resizable().scaledToFill()
                LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .black.opacity(0.65)],
                               startPoint: .top, endPoint: .bottom)
            }
        } else {
            brand
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySite", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName(WData.t("今日遗产", "今日遺產", "Today's Site", "今日の遺産", "오늘의 유산"))
        .description(WData.t("每天认识一项世界遗产", "每天認識一項世界遺產", "A World Heritage site every day",
                             "毎日ひとつの世界遺産", "매일 만나는 세계유산"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 足迹进度（订阅）

struct ProgressEntry: TimelineEntry {
    let date: Date
    let visited: Int
    let wish: Int
    let total: Int
    let isPro: Bool
}

struct ProgressProvider: TimelineProvider {
    private func current() -> ProgressEntry {
        let d = WData.defaults
        let total = d.integer(forKey: "totalCount")
        return ProgressEntry(date: Date(),
                             visited: d.integer(forKey: "visitedCount"),
                             wish: d.integer(forKey: "wishCount"),
                             total: total > 0 ? total : max(WData.sites.count, 1),
                             isPro: d.bool(forKey: "isPro"))
    }

    func placeholder(in context: Context) -> ProgressEntry { current() }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }
}

struct ProgressWidgetView: View {
    let entry: ProgressEntry

    var body: some View {
        Group {
            if entry.isPro {
                unlocked
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.title2)
                    Text(WData.t("订阅后可用", "訂閱後可用", "Available with Pro", "サブスク登録で利用可", "구독 후 이용 가능"))
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(brand)
    }

    private var unlocked: some View {
        let progress = Double(entry.visited) / Double(max(entry.total, 1))
        return VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(progress, entry.visited > 0 ? 0.015 : 0))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(entry.visited)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("/ \(entry.total)")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.8)
                }
            }
            .frame(width: 84, height: 84)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.caption2)
                Text("\(entry.wish)").font(.caption.weight(.bold))
                Text(WData.t("想去", "想去", "wish", "行きたい", "가고 싶은"))
                    .font(.caption2)
                    .opacity(0.85)
            }
        }
    }
}

struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Footprint", provider: ProgressProvider()) { entry in
            ProgressWidgetView(entry: entry)
        }
        .configurationDisplayName(WData.t("足迹进度", "足跡進度", "Footprint", "足あと", "발자취"))
        .description(WData.t("已到访的世界遗产数量", "已到訪的世界遺產數量", "World Heritage sites you have visited",
                             "訪れた世界遺産の数", "방문한 세계유산 수"))
        .supportedFamilies([.systemSmall])
    }
}

@main
struct HeritageWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        ProgressWidget()
    }
}
