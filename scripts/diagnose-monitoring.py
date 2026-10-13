#!/usr/bin/env python3
"""Read-only live probe of production scanner. Does not read credentials/log bodies.
Prints redacted metadata; use --output /private/path.json to retain results.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--output')
options = parser.parse_args()
root = Path(__file__).resolve().parent.parent
swift = r'''
import Foundation
@main struct Probe {
    static func main() throws {
        let defaults = UserDefaults(suiteName: "com.claudecode.menubar")!
        let enabled = ProviderPreferences.load(defaults: defaults)
        let start = Date()
        let detected = ProcessScanner.findUntrackedSessions(existingPids: [], enabledProviders: Set(MonitoredProvider.allCases))
        let selected = ProcessScanner.findUntrackedSessions(existingPids: [], enabledProviders: enabled)
        let rows: [[String: Any]] = detected.map { session in
            ["pid": session.pid, "provider": session.provider.rawValue,
             "enabled": enabled.contains(session.provider),
             "profile": session.profilePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "unknown",
             "terminal": session.terminalApp ?? "unknown", "status": session.state().status.rawValue]
        }
        let data = try JSONSerialization.data(withJSONObject: ["scan_seconds": Date().timeIntervalSince(start),
            "enabled": enabled.map(\.rawValue).sorted(), "selected_pids": selected.map(\.pid).sorted(), "detected": rows], options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
'''
files = ['Core/AppLanguage.swift', 'Core/MonitoredProvider.swift', 'Core/SessionState.swift',
         'Services/ProcessScanner.swift', 'Services/CodexHomeDiscovery.swift']
with tempfile.TemporaryDirectory(prefix='nyanbar-probe-') as temp:
    runner = Path(temp) / 'Probe.swift'
    runner.write_text(swift)
    binary = Path(temp) / 'probe'
    args = ['swiftc', '-swift-version', '5', '-parse-as-library']
    if os.environ.get('SDKROOT'):
        args += ['-sdk', os.environ['SDKROOT']]
    subprocess.run(args + [str(root / 'Sources/ClaudeMenuBar' / f) for f in files]
                   + [str(runner), '-o', str(binary)], check=True)
    # Independent OS baseline uses executable paths, never command arguments/prompts.
    baseline = subprocess.run(['ps', '-ww', '-U', str(os.getuid()), '-o', 'pid=,ppid=,comm='],
                              text=True, capture_output=True, check=True).stdout
    baseline_rows = []
    names = {'codex', 'claude', 'cursor-agent', 'copilot', 'opencode', 'ollama', 'grok', 'devin'}
    for line in baseline.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) == 3 and Path(parts[2]).name.lower() in names:
            baseline_rows.append({'pid': int(parts[0]), 'ppid': int(parts[1]), 'executable': Path(parts[2]).name})
    result = json.loads(subprocess.run([str(binary)], text=True, capture_output=True, check=True).stdout)
    result['os_baseline'] = baseline_rows
    result['observed_at_unix'] = time.time()
    output = json.dumps(result, ensure_ascii=False, indent=2)
    print(output)
    if options.output:
        target = Path(options.output).expanduser()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(output + '\n')
        target.chmod(0o600)
