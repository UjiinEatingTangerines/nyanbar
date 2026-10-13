#!/usr/bin/env python3
"""Run the provider regression suite with CLT-only Swift (no Testing macros).
Uses the same test bodies as swift test; no mocked production implementation.
Set SDKROOT to an installed macOS SDK when the default SDK is incompatible.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / 'Tests/ClaudeMenuBarTests/ProviderMonitoringTests.swift').read_text()
methods = re.findall(r'@Test func (\w+)\(', source)
source = source.replace('import Testing\n', '').replace('@testable import ClaudeMenuBar\n', '')
source = source.replace('@Test ', '').replace('#expect(', 'assert(').replace('#require(', 'require(')
source = '''import Foundation
func require<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "NyanBarTests", code: 1) }
    return value
}
''' + source
# Swift assert's autoclosure cannot throw; evaluate this round trip first.
source = source.replace('assert(try JSONDecoder().decode(SessionState.self, from: encoder.encode(observed)) == observed)',
                        'let decoded = try JSONDecoder().decode(SessionState.self, from: encoder.encode(observed))\n        assert(decoded == observed)')
source += '\n@main struct TestRunner { static func main() throws {\nlet tests = ProviderMonitoringTests()\n'
for name in methods:
    source += f'try tests.{name}()\nprint("PASS {name}")\n'
source += f'print("Passed {len(methods)} provider regression tests")\n}}}}\n'
files = ['Core/AppLanguage.swift', 'Core/MonitoredProvider.swift', 'Core/SessionState.swift', 'Core/SessionDirectoryWatcher.swift',
         'Services/ProcessScanner.swift', 'Services/CodexHomeDiscovery.swift']
with tempfile.TemporaryDirectory(prefix='nyanbar-tests-') as temp:
    runner = Path(temp) / 'Runner.swift'
    runner.write_text(source)
    binary = Path(temp) / 'tests'
    args = ['swiftc', '-swift-version', '5', '-parse-as-library']
    if os.environ.get('SDKROOT'):
        args += ['-sdk', os.environ['SDKROOT']]
    args += [str(root / 'Sources/ClaudeMenuBar' / f) for f in files]
    subprocess.run(args + [str(runner), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
