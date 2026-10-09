import SwiftUI

/// 完整名录：搜索、筛选、排序
struct CatalogView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "最新列入"
        case oldest = "最早列入"
        case name = "按名称"
        var id: String { rawValue }
        var title: String { T(rawValue) }
    }

    @State private var search = ""
    @State private var category: HeritageCategory? = nil
    @State private var region: String? = nil
    @State private var sort: SortMode = .newest
    @State private var dangerOnly = false

    private let store = DataStore.shared

    private var filtered: [Site] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var list = store.sites.filter { s in
            if let category = category, s.category != category { return false }
            if let region = region, !s.r.contains(region) { return false }
            if dangerOnly && !s.dg { return false }
            if q.isEmpty { return true }
            return s.n.lowercased().contains(q) || s.nt.lowercased().contains(q) || s.nj.lowercased().contains(q) || s.nk.lowercased().contains(q) || s.e.lowercased().contains(q)
                || s.countriesFull.lowercased().contains(q)
        }
        switch sort {
        case .newest: list.sort { ($0.y, $0.id) > ($1.y, $1.id) }
        case .oldest: list.sort { ($0.y, $0.id) < ($1.y, $1.id) }
        case .name: list.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        return list
    }

    private var isFiltering: Bool { category != nil || region != nil || dangerOnly }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { site in
                        NavigationLink(value: site) {
                            SiteRow(site: site)
                        }
                    }
                } header: {
                    Text(T("共 %d 项", filtered.count))
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: T("搜索遗产名称或国家"))
            .navigationTitle(T("世界遗产名录"))
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(T("排序"), selection: $sort) {
                            ForEach(SortMode.allCases) { m in
                                Text(m.title).tag(m)
                            }
                        }
                        Picker(T("类别"), selection: $category) {
                            Label(T("全部类别"), systemImage: "square.grid.2x2").tag(HeritageCategory?.none)
                            ForEach(HeritageCategory.allCases) { c in
                                Label(c.title, systemImage: c.symbol).tag(HeritageCategory?.some(c))
                            }
                        }
                        Picker(T("地区"), selection: $region) {
                            Label(T("全部地区"), systemImage: "globe").tag(String?.none)
                            ForEach(store.regions, id: \.self) { r in
                                Text(T(r)).tag(String?.some(r))
                            }
                        }
                        Toggle(isOn: $dangerOnly) {
                            Label(T("只看濒危遗产"), systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: isFiltering
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}
