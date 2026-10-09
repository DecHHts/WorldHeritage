import Foundation

/// 仅调试用：启动后直接进入某个页面，方便逐页检查。正式使用时 scene 保持为空。
enum DebugTour {
    static let scene = ""

    static var active: Bool {
        #if DEBUG
        return !scene.isEmpty
        #else
        return false
        #endif
    }

    static func on(_ name: String) -> Bool { active && scene == name }

    static var tab: Int {
        guard active else { return 0 }
        if scene.hasPrefix("theme:") { return 1 }
        switch scene {
        case "wheel": return 1
        case "plan", "assistant", "trip", "ai": return 4
        case "mine", "footprint", "offline", "themes": return 3
        default: return 0
        }
    }
}
