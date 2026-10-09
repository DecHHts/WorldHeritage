import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 设备端 Apple 智能：只负责“听懂一句话”和“写推荐理由”，候选遗产始终由 App 自己从名录里筛
enum AIEngine {
    enum Status {
        case ready
        /// 系统版本低于 iOS 26
        case unsupportedOS
        /// 设备不支持，或没有开启 Apple 智能，或模型还没下载好
        case unavailable
    }

    struct Parsed {
        var days: Int?
        var category: HeritageCategory?
        var region: String?
        var countryISO: String?
        var maxKm: Double?
    }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return .ready }
            return .unavailable
        }
        #endif
        return .unsupportedOS
    }

    private static var languageName: String {
        switch L10n.lang {
        case .hans: return "Simplified Chinese"
        case .hant: return "Traditional Chinese"
        case .en: return "English"
        case .ja: return "Japanese"
        case .ko: return "Korean"
        }
    }

    /// 把一句话转成筛选条件；失败返回 nil
    static func parse(_ text: String) async -> Parsed? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard status == .ready else { return nil }
            do {
                let session = LanguageModelSession(instructions: """
                You extract travel preferences from one short message written by a traveller. \
                The message may be in Chinese, English, Japanese or Korean. \
                Only report what the message actually says; use the documented empty values for anything not mentioned.
                """)
                let q = try await session.respond(to: text, generating: AIQuery.self).content
                var p = Parsed()
                if q.days > 0 { p.days = min(q.days, 14) }
                switch q.category.lowercased() {
                case "cultural": p.category = .cultural
                case "natural": p.category = .natural
                case "mixed": p.category = .mixed
                default: break
                }
                switch q.region.lowercased() {
                case "europe": p.region = "欧洲和北美"
                case "asia": p.region = "亚洲和太平洋"
                case "africa": p.region = "非洲"
                case "arab": p.region = "阿拉伯国家"
                case "latin": p.region = "拉丁美洲和加勒比"
                default: break
                }
                let iso = q.country.uppercased().trimmingCharacters(in: .whitespaces)
                if iso.count == 2, !DataStore.shared.sites(in: iso).isEmpty {
                    p.countryISO = iso
                    // 指定了国家就不再用大区限制
                    p.region = nil
                }
                if q.maxKm > 0 { p.maxKm = Double(q.maxKm) }
                return p
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// 根据 App 筛出的候选写一段推荐语；只允许使用给出的事实
    static func explain(request: String, sites: [Site]) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard status == .ready, !sites.isEmpty else { return nil }
            let cjk = L10n.lang != .en
            var facts = ""
            for (i, s) in sites.prefix(8).enumerated() {
                let summary = String(s.summary.prefix(cjk ? 90 : 220))
                facts += "\(i + 1). \(s.name) — \(s.countriesFull), \(s.category.title), \(s.y). \(summary)\n"
            }
            do {
                let session = LanguageModelSession(instructions: """
                You are a travel companion inside a UNESCO World Heritage app. \
                Write in \(languageName). Use only the facts given to you; never add sites, dates, prices or opening hours that are not in the list. \
                Keep it to one short paragraph of at most four sentences, with no lists and no headings.
                """)
                let prompt = """
                Traveller's request: \(request)

                Sites already chosen for this trip, in visiting order:
                \(facts)
                Explain briefly why this set fits the request and what ties the sites together.
                """
                let out = try await session.respond(to: prompt).content
                let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct AIQuery {
    @Guide(description: "Trip length in days. 0 if the message does not mention a length.")
    var days: Int
    @Guide(description: "Preferred kind of heritage: cultural, natural, mixed, or any if not mentioned.")
    var category: String
    @Guide(description: "Preferred world region: europe (Europe and North America), asia (Asia and the Pacific), africa, arab (Arab states), latin (Latin America and the Caribbean), or any if not mentioned.")
    var region: String
    @Guide(description: "ISO 3166-1 alpha-2 code of one specific country the traveller wants to visit, for example JP or IT. Empty string if no country is named.")
    var country: String
    @Guide(description: "Maximum distance from the departure point in kilometres. 0 if not mentioned.")
    var maxKm: Int
}
#endif
