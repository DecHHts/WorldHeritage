import Foundation
import StoreKit
import SwiftUI
import WidgetKit

/// 与小组件共享的少量状态（App Group）；拿不到共享容器时退回标准存储
enum Shared {
    static let group = "group.com.christopher.WorldHeritage"
    static let defaults: UserDefaults = UserDefaults(suiteName: group) ?? .standard

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// 订阅状态的全局只读镜像，供非界面代码查询
enum Pro {
    static var isPro = false
    /// 免费版“想去”清单的上限
    static let freeWishLimit = 30
}

/// 订阅功能清单（付费墙上展示）
enum ProFeature: String, CaseIterable, Identifiable {
    case assistant, trips, wheel, alerts, offline, footprint, voice, layers, themes, sync, widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assistant: return T("AI 旅行助手")
        case .trips: return T("行程规划")
        case .wheel: return T("条件转盘")
        case .alerts: return T("到达提醒与自动打卡")
        case .offline: return T("离线图片包")
        case .footprint: return T("年度回顾、徽章与足迹海报")
        case .voice: return T("语音讲解")
        case .layers: return T("自定义图层与时间轴")
        case .themes: return T("配色主题")
        case .sync: return T("无限收藏与 iCloud 同步")
        case .widgets: return T("足迹进度小组件")
        }
    }

    var detail: String {
        switch self {
        case .assistant: return T("用一句话说出想法，由设备上的 Apple 智能理解并推荐")
        case .trips: return T("把多个遗产串成路线，估算天数，导出到日历和地图")
        case .wheel: return T("按距离、季节、是否去过筛选，保存多个转盘")
        case .alerts: return T("走到遗产附近时提醒你，并自动记为去过")
        case .offline: return T("按国家下载遗产图片，没有网络也能看")
        case .footprint: return T("回顾每一年的足迹，生成可分享的海报")
        case .voice: return T("用当前语言朗读遗产简介")
        case .layers: return T("只看想去或没去过的，播放名录的历年变化，切换卫星底图")
        case .themes: return T("青瓷、黛蓝、樱粉、墨金、松绿五款配色")
        case .sync: return T("“想去”不再限 %d 项，并在你的设备间同步", Pro.freeWishLimit)
        case .widgets: return T("在主屏幕查看到访进度")
        }
    }

    var symbol: String {
        switch self {
        case .assistant: return "sparkles"
        case .trips: return "point.topleft.down.curvedto.point.bottomright.up.fill"
        case .wheel: return "dial.medium.fill"
        case .alerts: return "bell.badge.fill"
        case .offline: return "arrow.down.circle.fill"
        case .footprint: return "rosette"
        case .voice: return "speaker.wave.2.fill"
        case .layers: return "square.3.layers.3d.down.right"
        case .themes: return "paintpalette.fill"
        case .sync: return "icloud.fill"
        case .widgets: return "rectangle.3.group.fill"
        }
    }
}

/// StoreKit 2：两档订阅 + 一次买断
final class ProStore: ObservableObject {
    static let productIDs = ["wh.pro.monthly", "wh.pro.yearly", "wh.pro.lifetime"]

    @Published private(set) var purchased = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var loading = false
    @Published var message: String? = nil
    /// 仅调试版本可用：不经过购买直接解锁，方便测试
    @Published var debugUnlock: Bool {
        didSet {
            UserDefaults.standard.set(debugUnlock, forKey: "pro.debugUnlock")
            publish()
        }
    }

    var isPro: Bool { purchased || debugUnlock }

    private var updates: Task<Void, Never>? = nil

    init() {
        #if DEBUG
        debugUnlock = UserDefaults.standard.bool(forKey: "pro.debugUnlock")
        #else
        debugUnlock = false
        #endif
        purchased = UserDefaults.standard.bool(forKey: "pro.cached")
        if DebugTour.active { debugUnlock = !(DebugTour.on("paywall") || DebugTour.on("reset")) }
        publish()
        updates = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
        Task { [weak self] in
            await self?.refresh()
            await self?.loadProducts()
        }
    }

    deinit { updates?.cancel() }

    private func publish() {
        Pro.isPro = isPro
        Shared.defaults.set(isPro, forKey: "isPro")
        Shared.reloadWidgets()
    }

    @MainActor
    func loadProducts() async {
        if !products.isEmpty || loading { return }
        loading = true
        defer { loading = false }
        do {
            let list = try await Product.products(for: ProStore.productIDs)
            products = list.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    @MainActor
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               ProStore.productIDs.contains(t.productID),
               t.revocationDate == nil {
                active = true
            }
        }
        purchased = active
        UserDefaults.standard.set(active, forKey: "pro.cached")
        publish()
    }

    @MainActor
    func purchase(_ product: Product) async {
        message = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refresh()
                } else {
                    message = T("购买未能通过验证，请稍后再试。")
                }
            case .pending:
                message = T("购买正在等待批准。")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = T("购买没有完成，请稍后再试。")
        }
    }

    @MainActor
    func restore() async {
        message = nil
        try? await AppStore.sync()
        await refresh()
        if !purchased { message = T("没有找到可恢复的购买。") }
    }
}

// MARK: - 付费墙

struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(T("世遗漫游"))
                                .font(.title2.weight(.bold))
                            ProBadge()
                        }
                        Text(T("名录、地图和简介永久免费。订阅解锁规划、记录、离线和个性化功能。"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ProFeature.allCases) { f in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: f.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.title).font(.subheadline.weight(.semibold))
                                    Text(f.detail).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if pro.isPro {
                        Label(T("你已解锁全部功能"), systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if pro.products.isEmpty {
                        VStack(spacing: 8) {
                            if pro.loading { ProgressView() }
                            Text(pro.loading ? T("正在加载价格…") : T("暂时无法连接 App Store，请稍后再试。"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(pro.products, id: \.id) { product in
                                Button {
                                    busy = true
                                    Task {
                                        await pro.purchase(product)
                                        busy = false
                                        if pro.isPro { dismiss() }
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(planTitle(product)).font(.subheadline.weight(.semibold))
                                            Text(planNote(product)).font(.caption).opacity(0.85)
                                        }
                                        Spacer()
                                        Text(product.displayPrice).font(.headline)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(product.id == "wh.pro.yearly" ? .accentColor : Color(.systemGray))
                            }
                        }
                        .disabled(busy)
                    }

                    if let message = pro.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }

                    Button(T("恢复购买")) {
                        busy = true
                        Task {
                            await pro.restore()
                            busy = false
                        }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .disabled(busy)

                    Text(T("订阅会自动续期，可随时在系统“设置 > Apple ID > 订阅”中取消。买断为一次性付费。"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("关闭")) { dismiss() }
                }
            }
            .task { await pro.loadProducts() }
        }
    }

    private func planTitle(_ p: Product) -> String {
        switch p.id {
        case "wh.pro.monthly": return T("按月订阅")
        case "wh.pro.yearly": return T("按年订阅")
        default: return T("一次买断")
        }
    }

    private func planNote(_ p: Product) -> String {
        switch p.id {
        case "wh.pro.monthly": return T("每月自动续期")
        case "wh.pro.yearly": return T("每年自动续期，最划算")
        default: return T("一次付费，永久使用")
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(.white)
            .background(
                LinearGradient(colors: [Color(red: 0.93, green: 0.72, blue: 0.30),
                                        Color(red: 0.78, green: 0.52, blue: 0.16)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
    }
}

extension View {
    /// 在当前视图上挂一个付费墙
    func paywall(_ shown: Binding<Bool>) -> some View {
        sheet(isPresented: shown) { PaywallView() }
    }
}

/// 系统分享面板
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}
