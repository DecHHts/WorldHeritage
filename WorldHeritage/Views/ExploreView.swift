import SwiftUI
import MapKit

enum ExploreRoute: Hashable {
    case nearby
}

/// 一级地图：全屏热力分布；放大后显示具体遗产；点击国家进入二级地图
struct ExploreView: View {
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var pro: ProStore

    @State private var showPaywall = false
    @State private var playing = false
    private let ticker = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    @State private var path = NavigationPath()
    @State private var resetToken = 0
    @State private var locateToken = 0
    @State private var selected: Site? = nil
    @State private var showLocationHint = false

    private let store = DataStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // 地图铺满全屏，底部标签栏的玻璃直接盖在地图上
                WorldMapView(resetToken: resetToken,
                             locateToken: locateToken,
                             userCoordinate: location.location?.coordinate,
                             layer: settings.layer,
                             version: (settings.yearLimit ?? 0) * 100_000
                                 + favorites.wish.count * 131 + favorites.visited.count,
                             satellite: settings.satellite && pro.isPro,
                             onTapCountry: { country in path.append(country) },
                             onSelectSite: { site in selected = site })
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    HStack {
                        Spacer()
                        sideButtons
                    }
                    .padding(.top, 10)
                    Spacer()
                    if settings.yearLimit != nil { timeline }
                    legend
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Country.self) { country in
                CountryView(country: country)
            }
            .navigationDestination(for: ExploreRoute.self) { _ in
                NearbyView()
            }
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
            .sheet(item: $selected) { site in
                NavigationStack {
                    SiteDetailView(site: site, showsClose: true)
                }
            }
            .alert(T("无法获取位置"), isPresented: $showLocationHint) {
                Button(T("好"), role: .cancel) {}
            } message: {
                Text(location.isDenied
                     ? T("请在“设置 > 隐私与安全性 > 定位服务”中允许本 App 使用位置。")
                     : T("还没有拿到定位结果，请稍后再试。"))
            }
            .onAppear {
                location.request()
                if settings.layer.isPro && !pro.isPro { settings.layer = .all }
                if DebugTour.on("timeline") && settings.yearLimit == nil { settings.yearLimit = 1990 }
            }
            .onReceive(ticker) { _ in
                guard playing, let y = settings.yearLimit else { return }
                let last = store.yearRange.upperBound
                if y >= last {
                    playing = false
                } else {
                    settings.yearLimit = y + 1
                }
            }
            .paywall($showPaywall)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            // 标题即名录选择器
            Menu {
                Section(T("UNESCO 世界遗产名录")) {
                    Picker(T("名录"), selection: layerBinding) {
                        ForEach(HeatLayer.freeLayers) { layer in
                            Label(layer.title, systemImage: layer.symbol).tag(layer)
                        }
                    }
                }
                Section(pro.isPro ? T("我的图层") : T("我的图层（订阅）")) {
                    Picker(T("我的图层"), selection: layerBinding) {
                        ForEach(HeatLayer.proLayers) { layer in
                            Label(layer.title, systemImage: layer.symbol).tag(layer)
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(settings.layer.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    Text(T("%d 项 · %d 个国家",
                           store.sites(layer: settings.layer).count,
                           store.countryCount(layer: settings.layer)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                path.append(ExploreRoute.nearby)
            } label: {
                Label(T("附近"), systemImage: "location.north.line.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sideButtons: some View {
        VStack(spacing: 0) {
            Button {
                location.request()
                if location.location != nil {
                    locateToken += 1
                } else {
                    showLocationHint = location.isDenied || location.isAuthorized
                }
            } label: {
                Image(systemName: location.location != nil ? "location.fill" : "location")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(T("回到我的位置"))
            Divider().frame(width: 30)
            Button {
                resetToken += 1
            } label: {
                Image(systemName: "globe")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(T("回到世界视图"))
            Divider().frame(width: 30)
            Button {
                if !pro.isPro {
                    showPaywall = true
                } else if settings.yearLimit == nil {
                    settings.yearLimit = store.yearRange.lowerBound
                    playing = true
                } else {
                    playing = false
                    settings.yearLimit = nil
                }
            } label: {
                Image(systemName: settings.yearLimit == nil ? "clock.arrow.circlepath" : "clock.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(T("时间轴"))
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var layerBinding: Binding<HeatLayer> {
        Binding(
            get: { settings.layer },
            set: { layer in
                if layer.isPro && !pro.isPro {
                    showPaywall = true
                } else {
                    settings.layer = layer
                }
            })
    }

    /// 时间轴：拖动或播放，查看名录逐年增长
    private var timeline: some View {
        let range = store.yearRange
        let year = settings.yearLimit ?? range.upperBound
        return HStack(spacing: 10) {
            Button {
                if year >= range.upperBound { settings.yearLimit = range.lowerBound }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            Text(String(year))
                .font(.headline.monospacedDigit())
                .frame(width: 50)
            Slider(value: Binding(
                get: { Double(year) },
                set: { v in
                    playing = false
                    settings.yearLimit = Int(v.rounded())
                }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            Text(T("%d 项", store.sites(layer: settings.layer).count))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 8)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            Text(T("少")).font(.caption2).foregroundColor(.secondary)
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.45, blue: 1.0).opacity(0.5),
                    Color(red: 0.0, green: 0.8, blue: 0.65),
                    Color(red: 1.0, green: 0.85, blue: 0.1),
                    Color(red: 0.95, green: 0.15, blue: 0.1)
                ],
                startPoint: .leading, endPoint: .trailing)
                .frame(width: 60, height: 8)
                .clipShape(Capsule())
            Text(T("多")).font(.caption2).foregroundColor(.secondary)
            Divider().frame(height: 14)
            Text(T("放大看图钉 · 点国家进入"))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 4)
    }
}
