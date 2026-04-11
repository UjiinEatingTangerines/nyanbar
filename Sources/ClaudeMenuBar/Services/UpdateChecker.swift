import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String)
        case updating
        case updateDone
        case error(message: String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate),
                 (.updating, .updating), (.updateDone, .updateDone):
                return true
            case (.updateAvailable(let a), .updateAvailable(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default: return false
            }
        }
    }

    @Published private(set) var state: State = .idle

    private static let npmRegistryURL = "https://registry.npmjs.org/nyanbar/latest"

    static let currentVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    func checkForUpdate() {
        state = .checking

        guard let url = URL(string: Self.npmRegistryURL) else {
            state = .error(message: "Invalid URL")
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latestVersion = json["version"] as? String else {
                    state = .error(message: "Parse error")
                    return
                }

                if isNewer(latestVersion, than: Self.currentVersion) {
                    state = .updateAvailable(version: latestVersion)
                } else {
                    state = .upToDate
                    // Reset after 5 seconds
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if state == .upToDate { state = .idle }
                }
            } catch {
                state = .error(message: error.localizedDescription)
            }
        }
    }

    func performUpdate() {
        state = .updating

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-l", "-c", "npm install -g nyanbar && nyanbar install"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self?.state = .updateDone
                    } else {
                        self?.state = .error(message: "Update failed (exit \(task.terminationStatus))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.state = .error(message: error.localizedDescription)
                }
            }
        }
    }

    /// Compare semver strings: is `a` newer than `b`?
    private func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
