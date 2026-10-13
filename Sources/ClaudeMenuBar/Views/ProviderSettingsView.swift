import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var homes: [CodexHomeDiscovery.Home] = []

    private var lang: AppLanguage { settings.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.providerMonitoringTitle).font(.system(size: 13, weight: .semibold))
            Text(lang.providerMonitoringDescription)
                .font(.system(size: 10)).foregroundStyle(.secondary)
            ForEach(MonitoredProvider.allCases) { provider in
                Toggle(isOn: Binding(
                    get: { provider.canMonitor && settings.enabledProviders.contains(provider) },
                    set: { settings.setProvider(provider, enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(provider.displayName).font(.system(size: 12, weight: .medium))
                        Text(provider.capability(in: lang)).font(.system(size: 10)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!provider.canMonitor)
            }
            if settings.enabledProviders.contains(.codex) {
                Divider()
                Text(lang.codexProfilesTitle)
                    .font(.system(size: 11, weight: .medium))
                Text(lang.codexProfilesDescription)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                if homes.isEmpty {
                    Text(lang.noCodexHomes).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                ForEach(homes) { home in
                    Text(home.path).font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                }
                Button(lang.refreshCodexHomes) { refreshHomes() }.font(.system(size: 10))
            }
            Link(lang.providerCatalogSource, destination: URL(string:
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
