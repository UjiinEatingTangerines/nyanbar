# Optional provider monitoring

Settings → Provider monitoring stores opt-in selections locally. Only Claude is enabled on migration. Disable a provider to remove its sessions from the dashboard; enabling it triggers another scan. This does not install hooks or change any provider's configuration.

## Catalog and capabilities

Catalog snapshot: OpenUsage `66aada23bfbac5c5988617fdd6a0f8edbe106764`, verified from https://github.com/robinebers/openusage/blob/66aada23bfbac5c5988617fdd6a0f8edbe106764/Sources/OpenUsage/Providers/ProviderCatalog.swift . This is a public source snapshot, not a claim about the locally installed OpenUsage version. The implementation is independently written; no upstream source was copied.

- Claude: existing Claude Code hooks retain working / pending / completed states. Unhooked processes are shown as running only.
- Codex, Cursor, Antigravity, Copilot, Devin, Grok, Ollama, OpenCode: local executable detection only. Desktop app coverage depends on known executable names; Copilot covers the CLI, not editor extensions. Running does not establish an active AI task. Process exit does not trigger a completion notification.
- OpenRouter and Z.ai: listed with disabled toggles and an explanation. They are API services without attributable local sessions; quota/API integration remains unimplemented. This release does **not** provide full OpenUsage feature parity.
- OpenCode extensions such as OMO are not identified separately.

Provider names identify the client tool, not which model or billing account it uses. No quota endpoints, auth.json, environment files, Keychain secrets or log contents are read. Only current-user processes are scanned. Synthetic process observations stay in memory rather than overwriting Claude hook files.

## Codex profiles

Directory discovery includes CODEX_HOME inherited by NyanBar, ~/.codex, ~/.config/codex, ~/.codex-* and ~/.config/codex-*. Canonical paths deduplicate symlinks. This discovers directories, not authenticated accounts. Shell alias names are not recovered. A process is associated with a home when lsof reports an open session JSONL or the per-process `tmp/arg0/codex-arg0*/.lock` under exactly one discovered home. Missing or conflicting evidence leaves the profile unknown. Binary install paths and authentication files are not identity evidence. Authentication-based account deduplication, arbitrary custom homes hidden only in shell aliases, and account switching within a shared home are not implemented.

## Verification

With a complete compatible Xcode toolchain, use `swift test` and `swift build -c release`.

On the tested CLT installation, macOS 27 SDK cannot load SwiftUIMacros and Swift Testing's macro plugin is unavailable. The installed macOS 26.5 SDK builds the app:

```sh
swift build -c release --build-system native --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk python3 scripts/test-monitoring.py
git diff --check
```

The fallback runner compiles the actual production Swift files and executes the same test bodies using plain Swift assertions, without Testing macros. It does not replace production code with mocks. Twelve tests cover Korean localization, Orca terminal ancestry, runtime lock evidence, catalog, settings persistence, executable matching/false positives, tree deduplication, legacy decoding (including real pid-* hook IDs), Codex home boundaries, and file loading. The process smoke test starts a temporary /bin/sleep symlink named opencode to verify real ps/lsof discovery, opt-out and exit; it is not a claim that the OpenCode application itself was exercised.

For read-only live verification, run `SDKROOT=/path/to/compatible.sdk python3 scripts/diagnose-monitoring.py --output /private/path/result.json`. It compares production-scanner observations to an independent OS executable-path snapshot and separately checks the persisted provider selection. Outputs include PIDs and profile directory basenames but omit command arguments, project paths and credentials. Do not commit personal probe outputs.

Provider settings and session labels follow the existing Korean/Japanese/English setting, including changes while a card is visible. Orca terminal ancestors are recognized by their app path; card focus activates Orca, not a specific tab.

Release build and these tests passed. Live Codex and Devin process detection was exercised; GUI interaction, every vendor binary, quota integration and authenticated account matching were not all exercised. A pre-existing NSCache Sendable warning remains.
