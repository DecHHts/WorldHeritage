import SwiftUI
import CoreLocation

/// 目的地推荐：条件筛选人人可用；订阅用户可以直接用一句话描述（设备端 Apple 智能）
struct AssistantView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var trips: TripStore

    @State private var criteria = TripCriteria()
    @State private var results: [Site] = []
    @State private var searched = false
    @State private var query = ""
    @State private var lastQuery = ""
    @State private var aiText: String? = nil
    @State private var thinking = false
    @State private var note: String? = nil
    @State private var showPaywall = false
    @State private var savedTripID: UUID? = nil
    @FocusState private var typing: Bool

    private let store = DataStore.shared
    private var origin: CLLocationCoordinate2D? { location.location?.coordinate }

    var body: some View {
        List {
            Section {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(T("例如：7 天，喜欢自然景观，想去日本"), text: $query, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($typing)
                        .submitLabel(.send)
                    Button {
                        ask()
                    } label: {
                        if thinking {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill").font(.title2)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(thinking || query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                HStack(spacing: 6) {
                    Text(T("用一句话描述"))
                    if !pro.isPro { ProBadge() }
                }
            } footer: {
                Text(assistantFootnote)
            }

            Section {
                Stepper(value: $criteria.days, in: 1...14) {
                    LabeledContent(T("天数"), value: T("%d 天", criteria.days))
                }
                Picker(T("类别"), selection: $criteria.category) {
                    Text(T("全部类别")).tag(HeritageCategory?.none)
                    ForEach(HeritageCategory.allCases) { c in
                        Text(c.title).tag(HeritageCategory?.some(c))
                    }
                }
                Picker(T("地区"), selection: $criteria.region) {
                    Text(T("全球")).tag(String?.none)
                    ForEach(store.regions, id: \.self) { r in
                        Text(T(r)).tag(String?.some(r))
                    }
                }
                if let iso = criteria.countryISO, let c = store.country(iso) {
                    HStack {
                        LabeledContent(T("国家"), value: "\(c.flag) \(c.name)")
                        Button {
                            criteria.countryISO = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Picker(T("距离"), selection: $criteria.maxKm) {
                    Text(T("不限")).tag(Double?.none)
                    ForEach(Planner.distanceOptions, id: \.self) { km in
                        Text(T("%@ 以内", Planner.kmText(km))).tag(Double?.some(km))
                    }
                }
                .disabled(origin == nil)
                Toggle(T("避开当地冬季"), isOn: $criteria.seasonal)
                Toggle(T("不含去过的"), isOn: $criteria.excludeVisited)
                Button {
                    typing = false
                    aiText = nil
                    run()
                } label: {
                    Label(searched ? T("换一组") : T("开始推荐"), systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            } header: {
                Text(T("条件"))
            } footer: {
                Text(origin == nil
                     ? T("允许定位后可以按距离筛选。“避开当地冬季”按纬度粗略估算，仅供参考。")
                     : T("距离按你当前位置的直线距离计算。“避开当地冬季”按纬度粗略估算，仅供参考。"))
            }

            if searched {
                Section {
                    if let note = note {
                        Label(note, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    if let aiText = aiText {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(T("Apple 智能的建议"), systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.accentColor)
                            Text(aiText)
                                .font(.subheadline)
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 4)
                    }
                    if results.isEmpty {
                        Text(T("没有符合条件的遗产，放宽条件再试试。"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ForEach(Array(results.enumerated()), id: \.element.id) { item in
                        NavigationLink(value: item.element) {
                            HStack(spacing: 12) {
                                RemoteImage(url: item.element.imageURL, symbol: item.element.category.symbol)
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(item.offset + 1). \(item.element.name)")
                                        .font(.body.weight(.medium))
                                        .lineLimit(2)
                                    Text("\(item.element.flags) \(item.element.countryText)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(Planner.reason(item.element, origin: origin, wish: favorites.wish))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    if !results.isEmpty {
                        if let id = savedTripID {
                            NavigationLink(value: id) {
                                Label(T("已存为行程，点这里查看"), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button {
                                if pro.isPro {
                                    let t = trips.add(name: tripName, sites: results)
                                    savedTripID = t.id
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Label(T("存为行程"), systemImage: "square.and.arrow.down")
                                    if !pro.isPro { ProBadge() }
                                }
                            }
                        }
                    }
                } header: {
                    Text(results.isEmpty ? T("推荐") : T("推荐 · %d 项 · 约 %d 天",
                                                       results.count, Planner.estimatedDays(results)))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("帮我选目的地"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            location.request()
            if DebugTour.on("assistant") && !searched { run() }
            if DebugTour.on("ai") && !searched { query = "我有 6 天，喜欢自然风光，想去日本"; ask() }
        }
        .paywall($showPaywall)
    }

    private var assistantFootnote: String {
        switch AIEngine.status {
        case .ready:
            return T("由设备上的 Apple 智能理解你的话，内容不会离开这台设备。推荐的遗产始终来自名录本身。")
        case .unavailable:
            return T("这台设备暂时用不了 Apple 智能（设备不支持、未开启或模型尚未就绪）。可以直接用下面的条件。")
        case .unsupportedOS:
            return T("一句话描述需要 iOS 26 及以上系统和支持 Apple 智能的设备。可以直接用下面的条件。")
        }
    }

    private var tripName: String {
        if let iso = criteria.countryISO, let c = store.country(iso) {
            return T("%@ %d 日", c.name, Planner.estimatedDays(results))
        }
        if let first = results.first {
            return T("%@ %d 日", first.countryText, Planner.estimatedDays(results))
        }
        return T("新行程")
    }

    private func run() {
        let picked = Planner.recommend(criteria, origin: origin, wish: favorites.wish, visited: favorites.visited)
        withAnimation {
            results = picked
            searched = true
            savedTripID = nil
            note = nil
        }
    }

    private func ask() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard pro.isPro else {
            showPaywall = true
            return
        }
        typing = false
        guard AIEngine.status == .ready else {
            note = assistantFootnote
            searched = true
            return
        }
        thinking = true
        aiText = nil
        lastQuery = text
        Task { @MainActor in
            let parsed = await AIEngine.parse(text)
            if let p = parsed {
                var c = TripCriteria()
                c.excludeVisited = criteria.excludeVisited
                c.seasonal = criteria.seasonal
                c.days = p.days ?? criteria.days
                c.category = p.category
                c.region = p.region
                c.countryISO = p.countryISO
                c.maxKm = origin == nil ? nil : p.maxKm
                criteria = c
                run()
            } else {
                run()
                note = T("没能理解这句话，先按下面的条件推荐。")
            }
            var words: String? = nil
            if parsed != nil {
                words = await AIEngine.explain(request: text, sites: results)
            }
            if lastQuery == text { aiText = words }
            thinking = false
        }
    }
}
