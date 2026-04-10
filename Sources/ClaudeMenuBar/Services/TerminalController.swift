import Foundation
import AppKit

/// Controls terminal focus via cmux CLI or generic app activation.
struct TerminalController {
    private static let cmuxPath: String? = {
        let candidates = [
            "/Applications/cmux.app/Contents/Resources/bin/cmux",
            NSHomeDirectory() + "/Applications/cmux.app/Contents/Resources/bin/cmux",
            "/opt/homebrew/bin/cmux",
            "/usr/local/bin/cmux"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    static var isCmuxAvailable: Bool { cmuxPath != nil }

    /// Focus the terminal for a given session.
    @discardableResult
    static func focusSession(_ session: SessionState) -> Bool {
        // Try cmux panel focus first (most precise)
        if let panelId = session.cmuxSurfaceId ?? session.cmuxPanelId,
           isCmuxAvailable {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
            if panelId.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                return focusCmuxPanel(panelId)
            }
        }

        // Fallback: activate the terminal app by name
        if let app = session.terminalApp {
            return activateTerminalApp(app)
        }

        return false
    }

    // MARK: - cmux

    @discardableResult
    private static func focusCmuxPanel(_ panelId: String) -> Bool {
        guard let path = cmuxPath else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["focus-panel", "--panel", panelId]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                DispatchQueue.main.async { activateByBundleId("com.cmuxterm.app") }
                return true
            }
        } catch {}
        return false
    }

    // MARK: - Generic terminal activation

    @discardableResult
    private static func activateTerminalApp(_ terminalApp: String) -> Bool {
        // Map TERM_PROGRAM / bundle IDs to known bundle identifiers
        let bundleId: String? = {
            switch terminalApp {
            case "cmux", "com.cmuxterm.app":
                return "com.cmuxterm.app"
            case "ghostty", "com.mitchellh.ghostty":
                return "com.mitchellh.ghostty"
            case "iTerm.app", "iTerm2", "com.googlecode.iterm2":
                return "com.googlecode.iterm2"
            case "Apple_Terminal", "com.apple.Terminal":
                return "com.apple.Terminal"
            case "vscode", "com.microsoft.VSCode":
                return "com.microsoft.VSCode"
            case "WarpTerminal", "dev.warp.Warp-Stable":
                return "dev.warp.Warp-Stable"
            default:
                // If it looks like a bundle ID (contains dots), use it directly
                if terminalApp.contains(".") { return terminalApp }
                return nil
            }
        }()

        guard let id = bundleId else { return false }

        DispatchQueue.main.async {
            activateByBundleId(id)
        }
        return true
    }

    private static func activateByBundleId(_ bundleId: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate(options: [.activateAllWindows])
        }
    }
}
