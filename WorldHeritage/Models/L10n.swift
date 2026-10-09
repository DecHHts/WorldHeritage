import Foundation
import SwiftUI

/// App 实际使用的语言
enum Lang: String {
    case hans, hant, en, ja, ko

    var locale: Locale {
        switch self {
        case .hans: return Locale(identifier: "zh-Hans")
        case .hant: return Locale(identifier: "zh-Hant")
        case .en: return Locale(identifier: "en")
        case .ja: return Locale(identifier: "ja")
        case .ko: return Locale(identifier: "ko")
        }
    }
}

/// 用户的语言设置：跟随系统，或单独指定
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, hans, hant, en, ja, ko

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return T("跟随系统")
        case .hans: return "简体中文"
        case .hant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }
}

enum L10n {
    static var lang: Lang = .hans

    static func resolve(_ setting: AppLanguage) -> Lang {
        switch setting {
        case .hans: return .hans
        case .hant: return .hant
        case .en: return .en
        case .ja: return .ja
        case .ko: return .ko
        case .system:
            let code = (Locale.preferredLanguages.first ?? "en").lowercased()
            if code.hasPrefix("zh") {
                if code.contains("hant") || code.hasSuffix("-tw") || code.hasSuffix("-hk") || code.hasSuffix("-mo") {
                    return .hant
                }
                return .hans
            }
            if code.hasPrefix("ja") { return .ja }
            if code.hasPrefix("ko") { return .ko }
            return .en
        }
    }

    /// 以简体中文原文为键查表
    static func t(_ key: String) -> String {
        if lang == .hans { return key }
        guard let row = Strings.table[key] else { return key }
        switch lang {
        case .hans: return key
        case .hant: return row[0]
        case .en: return row[1]
        case .ja: return row[2]
        case .ko: return row[3]
        }
    }
}

func T(_ key: String) -> String { L10n.t(key) }

func T(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.t(key), arguments: args)
}

/// 首页热力图可选的名录 / 图层
enum HeatLayer: String, CaseIterable, Identifiable {
    case all, cultural, natural, mixed, danger, wish, unvisited

    /// 订阅用户的自定义图层
    static let proLayers: [HeatLayer] = [.wish, .unvisited]
    static let freeLayers: [HeatLayer] = [.all, .cultural, .natural, .mixed, .danger]
    var isPro: Bool { HeatLayer.proLayers.contains(self) }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return T("全部世界遗产")
        case .cultural: return T("文化遗产")
        case .natural: return T("自然遗产")
        case .mixed: return T("混合遗产")
        case .danger: return T("濒危遗产")
        case .wish: return T("我想去的")
        case .unvisited: return T("还没去过的")
        }
    }

    var symbol: String {
        switch self {
        case .all: return "globe.asia.australia.fill"
        case .cultural: return "building.columns.fill"
        case .natural: return "leaf.fill"
        case .mixed: return "mountain.2.fill"
        case .danger: return "exclamationmark.triangle.fill"
        case .wish: return "heart.fill"
        case .unvisited: return "circle.dashed"
        }
    }

    func contains(_ site: Site) -> Bool {
        switch self {
        case .all: return true
        case .cultural: return site.k == "C"
        case .natural: return site.k == "N"
        case .mixed: return site.k == "M"
        case .danger: return site.dg
        case .wish: return FavoritesStore.current?.wish.contains(site.id) ?? false
        case .unvisited: return !(FavoritesStore.current?.visited.contains(site.id) ?? false)
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app.language")
            L10n.lang = L10n.resolve(language)
            Shared.defaults.set(L10n.lang.rawValue, forKey: "lang")
            Shared.reloadWidgets()
            if dailyOn { Notifier.shared.scheduleDaily() }
        }
    }

    @Published var layer: HeatLayer {
        didSet { UserDefaults.standard.set(layer.rawValue, forKey: "explore.layer") }
    }

    /// 时间轴：只显示该年份及以前列入的遗产；nil 表示不限
    @Published var yearLimit: Int? = nil {
        didSet { DataStore.yearLimit = yearLimit }
    }

    /// 卫星底图（订阅功能）
    @Published var satellite: Bool {
        didSet { UserDefaults.standard.set(satellite, forKey: "map.satellite") }
    }

    /// 每日“今日遗产”通知
    @Published var dailyOn: Bool {
        didSet { UserDefaults.standard.set(dailyOn, forKey: "notify.daily") }
    }

    /// 配色主题
    @Published var themeID: String {
        didSet {
            UserDefaults.standard.set(themeID, forKey: "app.theme")
            Theme.current = Theme.find(themeID)
        }
    }

    var theme: Theme { Theme.find(themeID) }

    var lang: Lang { L10n.lang }

    init() {
        let d = UserDefaults.standard
        let saved = AppLanguage(rawValue: d.string(forKey: "app.language") ?? "") ?? .system
        language = saved
        layer = HeatLayer(rawValue: d.string(forKey: "explore.layer") ?? "") ?? .all
        satellite = d.bool(forKey: "map.satellite")
        themeID = d.string(forKey: "app.theme") ?? "ochre"
        Theme.current = Theme.find(d.string(forKey: "app.theme") ?? "ochre")
        dailyOn = d.bool(forKey: "notify.daily")
        L10n.lang = L10n.resolve(saved)
        Shared.defaults.set(L10n.lang.rawValue, forKey: "lang")
    }
}
