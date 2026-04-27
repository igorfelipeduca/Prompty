import Foundation
import AppKit

enum TerminalChoice: String, CaseIterable, Identifiable {
    case terminal  = "com.apple.Terminal"
    case iterm     = "com.googlecode.iterm2"
    case warp      = "dev.warp.Warp-Stable"
    case ghostty   = "com.mitchellh.ghostty"
    case hyper     = "co.zeit.hyper"
    case kitty     = "net.kovidgoyal.kitty"
    case alacritty = "io.alacritty"
    case wezterm   = "com.github.wez.wezterm"

    var id: String { rawValue }
    var bundleID: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal:  return "Terminal"
        case .iterm:     return "iTerm"
        case .warp:      return "Warp"
        case .ghostty:   return "Ghostty"
        case .hyper:     return "Hyper"
        case .kitty:     return "kitty"
        case .alacritty: return "Alacritty"
        case .wezterm:   return "WezTerm"
        }
    }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var isInstalled: Bool { appURL != nil }

    static var installed: [TerminalChoice] {
        allCases.filter { $0.isInstalled }
    }

    var icon: NSImage? {
        guard let url = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
