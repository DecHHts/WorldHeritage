import SwiftUI
import MapKit

/// 二级地图：某个国家范围内的遗产分布（跟随首页选择的名录）
struct CountryView: View {
    let country: Country

    @EnvironmentObject private var settings: AppSettings
    @State private var filter: HeritageCategory? = nil
    @State private var selected: Site? = nil
    @State private var showPaywall = false
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var offline: OfflineStore

    private var allSites: [Site] {
        DataStore.shared.sites(in: country.iso, layer: settings.layer).sorted { $0.y < $1.y }
    }

    private var sites: [Site] {
        guard let filter = filter else { return allSites }
        return allSites.filter { $0.category == filter }
    }

    /// 首页已经按类别筛选时，不再重复显示类别切换
    private var showsCategoryPicker: Bool {
        settings.layer == .all || settings.layer == .danger
    }

    var body: some View {
        VStack(spacing: 0) {
            CountryMapView(country: country, sites: sites) { site in
                selected = site
            }
            .ignoresSafeArea(edges: .horizontal)

            bottomPanel
        }
        .navigationTitle("\(country.flag) \(country.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let p = offline.progress[country.iso] {
                    ProgressView(value: p).frame(width: 44)
                } else if offline.downloaded.contains(country.iso) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        .accessibilityLabel(T("已下载离线图片"))
                } else {
                    Button {
                        if pro.isPro {
                            Task { await offline.download(country.iso) }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .accessibilityLabel(T("下载离线图片"))
                }
            }
        }
        .paywall($showPaywall)
        .sheet(item: $selected) { site in
            NavigationStack {
                SiteDetailView(site: site, showsClose: true)
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if allSites.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "mappin.slash")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(T("%@：当前名录下暂无条目", country.name))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(.systemGroupedBackground))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(T("%d 项", sites.count))
                            .font(.subheadline.weight(.semibold))
                        Text(settings.layer.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if showsCategoryPicker {
                        Picker(T("类别"), selection: $filter) {
                            Text(T("全部")).tag(HeritageCategory?.none)
                            ForEach(HeritageCategory.allCases) { c in
                                Text(c.shortTitle).tag(HeritageCategory?.some(c))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if sites.isEmpty {
                    Text(T("该类别下暂无遗产"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(sites) { site in
                                Button {
                                    selected = site
                                } label: {
                                    SiteCard(site: site)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .frame(height: 186)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}
