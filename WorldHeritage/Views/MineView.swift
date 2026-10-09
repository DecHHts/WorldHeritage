import SwiftUI

/// 我的足迹：进度、足迹地图、想去 / 去过清单、语言设置
struct MineView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var location: LocationManager
    @State private var tab = 0
    @State private var showPaywall = false
    @State private var path = NavigationPath()

    private let store = DataStore.shared

    private var list: [Site] { tab == 0 ? favorites.wishSites : favorites.visitedSites }
    private var hasAny: Bool { !favorites.wish.isEmpty || !favorites.visited.isEmpty }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    hero
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if hasAny {
                    Section {
                        footprint
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    Button {
                        if pro.isPro { path.append(MineRoute.footprint) } else { showPaywall = true }
                    } label: {
                        proRow(T("回顾与徽章"), symbol: "rosette", detail: T("年度回顾、徽章、足迹海报"))
                    }
                    Button {
                        if pro.isPro { path.append(MineRoute.offline) } else { showPaywall = true }
                    } label: {
                        proRow(T("离线图片包"), symbol: "arrow.down.circle.fill", detail: T("按国家下载遗产图片"))
                    }
                }

                Section {
                    Picker(T("清单"), selection: $tab) {
                        Text("\(T("想去")) \(favorites.wish.count)").tag(0)
                        Text("\(T("去过")) \(favorites.visited.count)").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)

                    if list.isEmpty {
                        emptyState
                    } else {
                        ForEach(list) { site in
                            NavigationLink(value: site) {
                                SiteRow(site: site, thumbnail: true)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if tab == 0 {
                                        favorites.toggleWish(site)
                                    } else {
                                        favorites.toggleVisited(site)
                                    }
                                } label: {
                                    Label(T("移除"), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if tab == 0 {
                                    Button {
                                        if !favorites.isVisited(site) { favorites.toggleVisited(site) }
                                    } label: {
                                        Label(T("去过"), systemImage: "checkmark.seal.fill")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                }

                if tab == 0 && !pro.isPro {
                    Section {
                        Text(T("免费版“想去”最多 %d 项，已用 %d 项。", Pro.freeWishLimit, favorites.wish.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }

                subscriptionSection
                settingsSection

                Section {
                    LabeledContent(T("数据来源"), value: "UNESCO World Heritage Centre")
                    Text(T("名录、列入年份、入选标准与简介来自联合国教科文组织世界遗产中心公开数据；部分官方暂无中文的条目为编译译文。国家边界仅用于点击识别，不代表任何立场。"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text(T("关于"))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(T("我的足迹"))
            .navigationDestination(for: Site.self) { site in
                SiteDetailView(site: site)
            }
            .navigationDestination(for: MineRoute.self) { route in
                switch route {
                case .footprint: FootprintProView()
                case .offline: OfflineView()
                case .themes: ThemeView()
                }
            }
            .onAppear {
                guard path.isEmpty else { return }
                if DebugTour.on("footprint") { path.append(MineRoute.footprint) }
                if DebugTour.on("offline") { path.append(MineRoute.offline) }
                if DebugTour.on("themes") { path.append(MineRoute.themes) }
            }
            .paywall($showPaywall)
            .onChange(of: pro.isPro) { on in
                if on { favorites.syncNow() }
                if !on && settings.theme.isPro { settings.themeID = "ochre" }
            }
        }
    }

    private var subscriptionSection: some View {
        Section {
            if pro.isPro {
                Label(T("已解锁全部功能"), systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Label(T("解锁全部功能"), systemImage: "sparkles")
                        Spacer()
                        ProBadge()
                    }
                }
            }
            #if DEBUG
            Toggle(isOn: $pro.debugUnlock) {
                Label(T("调试：模拟已订阅"), systemImage: "hammer")
            }
            #endif
        } header: {
            Text(T("订阅"))
        }
    }

    private var settingsSection: some View {
        Section {
            Picker(selection: $settings.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.title).tag(lang)
                }
            } label: {
                Label(T("语言"), systemImage: "globe")
            }
            NavigationLink(value: MineRoute.themes) {
                HStack {
                    Label(T("主题"), systemImage: "paintpalette")
                    Spacer()
                    Text(settings.theme.name).foregroundColor(.secondary)
                }
            }
            Toggle(isOn: Binding(
                get: { settings.dailyOn },
                set: { on in
                    if on {
                        Notifier.shared.requestPermission { ok in
                            settings.dailyOn = ok
                            if ok { Notifier.shared.scheduleDaily() }
                        }
                    } else {
                        settings.dailyOn = false
                        Notifier.shared.cancelDaily()
                    }
                })) {
                Label(T("每天推荐一项遗产"), systemImage: "bell")
            }
            Toggle(isOn: Binding(
                get: { location.alertsOn && pro.isPro },
                set: { on in
                    guard pro.isPro else {
                        showPaywall = true
                        return
                    }
                    if on {
                        Notifier.shared.requestPermission { _ in location.alertsOn = true }
                    } else {
                        location.alertsOn = false
                    }
                })) {
                proLabel(T("到达遗产附近时提醒"), symbol: "bell.badge")
            }
            if location.alertsOn && pro.isPro {
                Toggle(isOn: $location.autoCheckIn) {
                    Label(T("到达时自动记为去过"), systemImage: "checkmark.seal")
                }
            }
            Toggle(isOn: Binding(
                get: { settings.satellite && pro.isPro },
                set: { on in
                    if pro.isPro { settings.satellite = on } else { showPaywall = true }
                })) {
                proLabel(T("卫星底图"), symbol: "globe.americas")
            }
            HStack {
                proLabel(T("iCloud 同步"), symbol: "icloud")
                Spacer()
                Text(pro.isPro ? T("已开启") : T("未开启"))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(T("设置"))
        } footer: {
            Text(T("到达提醒需要把定位权限设为“始终”，才能在 App 关闭时也生效；距离遗产约 3 公里内视为到达。"))
        }
    }

    private func proLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: symbol)
            if !pro.isPro { ProBadge() }
        }
    }

    private func proRow(_ title: String, symbol: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.body.weight(.medium)).foregroundColor(.primary)
                    if !pro.isPro { ProBadge() }
                }
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
    }

    // MARK: 顶部进度卡

    private var hero: some View {
        let total = max(store.sites.count, 1)
        let visited = favorites.visited.count
        let progress = Double(visited) / Double(total)

        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: max(progress, visited > 0 ? 0.012 : 0))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(visited)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("/ \(total)")
                        .font(.caption2.weight(.medium))
                        .opacity(0.8)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(T("已到访世界遗产"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: "%.1f%%", progress * 100))
                        .font(.caption)
                        .opacity(0.85)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        miniStat("heart.fill", favorites.wish.count, T("想去"))
                        miniStat("flag.fill", favorites.visitedCountryCount, T("国家"))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        miniStat("heart.fill", favorites.wish.count, T("想去"))
                        miniStat("flag.fill", favorites.visitedCountryCount, T("国家"))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(settings.theme.hero)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func miniStat(_ symbol: String, _ value: Int, _ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2)
            Text("\(value)").font(.subheadline.weight(.bold).monospacedDigit())
            Text(title).font(.caption).opacity(0.85)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
    }

    // MARK: 足迹地图

    private var footprint: some View {
        ZStack(alignment: .bottomLeading) {
            FootprintWorldView(wish: favorites.wishSites, visited: favorites.visitedSites)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 40)
            HStack(spacing: 12) {
                legendDot(.green, T("去过"))
                legendDot(.pink, T("想去"))
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: tab == 0 ? "heart" : "checkmark.seal")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(tab == 0 ? T("还没有想去的地方，在遗产详情页点“想去”收藏") : T("还没有去过的记录，在遗产详情页点“去过”打卡"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

enum MineRoute: Hashable {
    case footprint, offline, themes
}

/// 离线图片包管理
struct OfflineView: View {
    @EnvironmentObject private var offline: OfflineStore

    private var countries: [Country] {
        DataStore.shared.countries
            .filter { !DataStore.shared.sites(in: $0.iso).isEmpty }
            .sorted {
                let a = offline.downloaded.contains($0.iso), b = offline.downloaded.contains($1.iso)
                if a != b { return a }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Section {
                ForEach(countries) { c in
                    HStack(spacing: 12) {
                        Text(c.flag).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name)
                            Text(T("%d 项", DataStore.shared.sites(in: c.iso).count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let p = offline.progress[c.iso] {
                            ProgressView(value: p)
                                .frame(width: 70)
                        } else if offline.downloaded.contains(c.iso) {
                            Button(role: .destructive) {
                                offline.remove(c.iso)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button {
                                Task { await offline.download(c.iso) }
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text(T("已占用 %@", offline.sizeText))
            } footer: {
                Text(T("离线包保存遗产图片；名称、简介和名录数据本身就在 App 内，无需下载。底图由 Apple 地图提供，不能离线保存。"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(T("离线图片包"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
