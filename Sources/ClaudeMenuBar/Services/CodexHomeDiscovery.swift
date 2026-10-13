import Foundation

/// Directory names only. Never opens auth.json, .env, logs or Keychain.
struct CodexHomeDiscovery {
    struct Home: Identifiable, Equatable {
        let path: String
        var id: String { path }
        var label: String { URL(fileURLWithPath: path).lastPathComponent }
    }

    static func discover(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [Home] {
        let config = home.appendingPathComponent(".config")
        var candidates = [home.appendingPathComponent(".codex"), config.appendingPathComponent("codex")]
        if let raw = environment["CODEX_HOME"], !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            let expanded = raw.hasPrefix("~/") ? home.path + String(raw.dropFirst()) : raw
            // Relative environment paths are ambiguous in a GUI process.
            if expanded.hasPrefix("/") { candidates.insert(URL(fileURLWithPath: expanded), at: 0) }
        }
        for (parent, prefix) in [(home, ".codex-"), (config, "codex-")] {
            let children = (try? fileManager.contentsOfDirectory(at: parent,
                includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants])) ?? []
            candidates += children.filter { $0.lastPathComponent.hasPrefix(prefix) }.sorted { $0.path < $1.path }
        }
        var seen = Set<String>()
        return candidates.compactMap { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            let path = url.resolvingSymlinksInPath().standardizedFileURL.path
            return seen.insert(path).inserted ? Home(path: path) : nil
        }
    }

    /// Only an actually open session file associates a process with a home.
    /// Folder existence, cwd and inherited GUI environment do not prove identity.
    static func associatedHome(openPaths: [String], homes: [Home]) -> Home? {
        let matches = homes.filter { home in
            openPaths.contains { path in
                let canonical = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
                return canonical.hasPrefix(home.path + "/sessions/") && canonical.hasSuffix(".jsonl")
            }
        }
        return matches.count == 1 ? matches[0] : nil
    }
}
