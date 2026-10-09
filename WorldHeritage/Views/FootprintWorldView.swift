import SwiftUI
import CoreLocation

/// “我的足迹”里的世界缩略图：整幅世界轮廓 + 去过的国家着色 + 想去 / 去过的点
struct FootprintWorldView: View {
    var wish: [Site]
    var visited: [Site]

    private static let maxLat = 84.0
    private static let minLat = -58.0
    static let aspect: CGFloat = CGFloat(360.0 / (maxLat - minLat))

    private static func unitPoint(lat: Double, lon: Double) -> CGPoint {
        CGPoint(x: (lon + 180) / 360, y: (maxLat - lat) / (maxLat - minLat))
    }

    private static func path(for country: Country) -> Path {
        var p = Path()
        for poly in country.polygons where poly.maxLat > minLat {
            // 跳过在缩略图上看不见的小岛
            if poly.area < 0.3 && country.polygons.count > 1 { continue }
            var first = true
            for c in poly.ring {
                let pt = unitPoint(lat: c.latitude, lon: c.longitude)
                if first { p.move(to: pt); first = false } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        return p
    }

    private static let countryPaths: [String: Path] = {
        var dict: [String: Path] = [:]
        for c in DataStore.shared.countries where c.iso != "AQ" { dict[c.iso] = path(for: c) }
        return dict
    }()

    private static let worldPath: Path = {
        var p = Path()
        for (_, cp) in countryPaths { p.addPath(cp) }
        return p
    }()

    var body: some View {
        Canvas { ctx, size in
            let t = CGAffineTransform(scaleX: size.width, y: size.height)
            ctx.fill(FootprintWorldView.worldPath.applying(t), with: .color(Color(.systemGray3)))

            var visitedISO = Set<String>()
            for s in visited { for c in s.cc { visitedISO.insert(c) } }
            for iso in visitedISO {
                if let cp = FootprintWorldView.countryPaths[iso] {
                    ctx.fill(cp.applying(t), with: .color(Color.green.opacity(0.55)))
                }
            }

            let visitedIDs = Set(visited.map { $0.id })
            var dots: [(SitePoint, Color)] = []
            for s in wish where !visitedIDs.contains(s.id) { for p in s.p { dots.append((p, .pink)) } }
            for s in visited { for p in s.p { dots.append((p, .green)) } }
            for (p, color) in dots {
                let u = FootprintWorldView.unitPoint(lat: p.la, lon: p.lo)
                let c = CGPoint(x: u.x * size.width, y: u.y * size.height)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(color))
            }
        }
        .aspectRatio(FootprintWorldView.aspect, contentMode: .fit)
    }
}
