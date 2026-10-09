import MapKit
import UIKit

/// 覆盖全世界的热力图图层
final class HeatOverlay: NSObject, MKOverlay {
    let points: [MKMapPoint]
    let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let boundingMapRect = MKMapRect.world

    init(points: [MKMapPoint]) {
        self.points = points
        super.init()
    }
}

/// 按瓦片计算核密度并映射到色带。密度是世界坐标的函数，所以相邻瓦片可以无缝拼接。
final class HeatRenderer: MKOverlayRenderer {
    private let points: [MKMapPoint]
    private static let lut: [UInt8] = HeatRenderer.makeLUT()
    private static let grid = 96
    /// 单个热点在屏幕上的半径（pt）
    private static let screenRadius = 26.0

    init(heat: HeatOverlay) {
        points = heat.points
        super.init(overlay: heat)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let radius = HeatRenderer.screenRadius / Double(zoomScale)
        let sigma = radius / 2.2
        let inv2s2 = 1.0 / (2.0 * sigma * sigma)
        let r2 = radius * radius

        let minX = mapRect.origin.x
        let minY = mapRect.origin.y
        let maxX = minX + mapRect.size.width
        let maxY = minY + mapRect.size.height

        var local: [MKMapPoint] = []
        for p in points {
            if p.x >= minX - radius && p.x <= maxX + radius && p.y >= minY - radius && p.y <= maxY + radius {
                local.append(p)
            }
        }
        if local.isEmpty { return }

        let n = HeatRenderer.grid
        let cellW = mapRect.size.width / Double(n)
        let cellH = mapRect.size.height / Double(n)
        if cellW <= 0 || cellH <= 0 { return }
        var density = [Float](repeating: 0, count: n * n)

        for p in local {
            let cx = (p.x - minX) / cellW
            let cy = (p.y - minY) / cellH
            let rx = radius / cellW
            let ry = radius / cellH
            let i0 = max(0, Int((cx - rx).rounded(.down)))
            let i1 = min(n - 1, Int((cx + rx).rounded(.up)))
            let j0 = max(0, Int((cy - ry).rounded(.down)))
            let j1 = min(n - 1, Int((cy + ry).rounded(.up)))
            if i0 > i1 || j0 > j1 { continue }
            for j in j0...j1 {
                let dy = (Double(j) + 0.5 - cy) * cellH
                for i in i0...i1 {
                    let dx = (Double(i) + 0.5 - cx) * cellW
                    let d2 = dx * dx + dy * dy
                    if d2 < r2 {
                        density[j * n + i] += Float(exp(-d2 * inv2s2))
                    }
                }
            }
        }

        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        let lut = HeatRenderer.lut
        for idx in 0..<(n * n) {
            let d = density[idx]
            if d <= 0.02 { continue }
            let v = 1.0 - exp(-0.5 * Double(d))
            let li = min(255, max(0, Int(v * 255.0))) * 4
            let o = idx * 4
            pixels[o] = lut[li]
            pixels[o + 1] = lut[li + 1]
            pixels[o + 2] = lut[li + 2]
            pixels[o + 3] = lut[li + 3]
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let image: CGImage? = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let ctx = CGContext(data: buffer.baseAddress,
                                      width: n,
                                      height: n,
                                      bitsPerComponent: 8,
                                      bytesPerRow: n * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
        guard let cgImage = image else { return }

        let target = rect(for: mapRect)
        UIGraphicsPushContext(context)
        context.interpolationQuality = .medium
        UIImage(cgImage: cgImage).draw(in: target, blendMode: .normal, alpha: 0.9)
        UIGraphicsPopContext()
    }

    /// 256 级色带（预乘 alpha 的 RGBA）：透明 → 蓝 → 青绿 → 黄 → 红
    private static func makeLUT() -> [UInt8] {
        let stops: [(pos: Double, r: Double, g: Double, b: Double, a: Double)] = [
            (0.00, 0.20, 0.40, 1.00, 0.00),
            (0.20, 0.20, 0.45, 1.00, 0.35),
            (0.45, 0.00, 0.80, 0.65, 0.55),
            (0.70, 1.00, 0.85, 0.10, 0.72),
            (1.00, 0.95, 0.15, 0.10, 0.85)
        ]
        var out = [UInt8](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let t = Double(i) / 255.0
            var k = 0
            while k < stops.count - 2 && t > stops[k + 1].pos { k += 1 }
            let a = stops[k], b = stops[k + 1]
            let f = min(1, max(0, (t - a.pos) / (b.pos - a.pos)))
            let r = a.r + (b.r - a.r) * f
            let g = a.g + (b.g - a.g) * f
            let bl = a.b + (b.b - a.b) * f
            let al = a.a + (b.a - a.a) * f
            out[i * 4] = UInt8(r * al * 255)
            out[i * 4 + 1] = UInt8(g * al * 255)
            out[i * 4 + 2] = UInt8(bl * al * 255)
            out[i * 4 + 3] = UInt8(al * 255)
        }
        return out
    }
}
