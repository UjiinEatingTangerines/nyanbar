import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var homes: [CodexHomeDiscovery.Home] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider monitoring").font(.system(size: 13, weight: .semibold))
            Text("Only Claude is enabled by default. Other tools require opt-in. Running means a local process exists, not that AI is working. No usage APIs or credentials are read.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            ForEach(MonitoredProvider.allCases) { provider in
                Toggle(isOn: Binding(
                    get: { provider.canMonitor && settings.enabledProviders.contains(provider) },
                    set: { settings.setProvider(provider, enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(provider.displayName).font(.system(size: 12, weight: .medium))
                        Text(provider.capability).font(.system(size: 10)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!provider.canMonitor)
            }
            if settings.enabledProviders.contains(.codex) {
                Divider()
                Text("Codex homes / profiles — not verified accounts")
                    .font(.system(size: 11, weight: .medium))
                Text("Directory discovery does not imply a running session. A process is linked to a home only while its session file is visibly open; otherwise its profile is unknown.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                if homes.isEmpty {
                    Text("No home directories found.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                ForEach(homes) { home in
                    Text(home.path).font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                }
                Button("Refresh homes") { refreshHomes() }.font(.system(size: 10))
            }
            Link("Catalog: OpenUsage public main (source snapshot)", destination: URL(string:
                "https://github.com/robinebers/openusage/blob/66aada23bfbac5c5988617fdd6a0f8edbe106764/Sources/OpenUsage/Providers/ProviderCatalog.swift")!)
                .font(.system(size: 10))
        }
        .onAppear { if settings.enabledProviders.contains(.codex) { refreshHomes() } }
        .onChange(of: settings.enabledProviders) { _, providers in
            if providers.contains(.codex) { refreshHomes() } else { homes = [] }
        }
    }

    private func refreshHomes() {
        Task {
            let discovered = await Task.detached(priority: .utility) { CodexHomeDiscovery.discover() }.value
            homes = settings.enabledProviders.contains(.codex) ? discovered : []
        }
    }
}
