import 'dart:io';
import 'process_runner.dart';

/// Manages a macOS launchd plist for periodic repo scanning.
class LaunchdService {
  final ProcessRunner _runner;

  static const _label = 'com.projectstatus.scanner';
  static String get _plistPath =>
      '${Platform.environment['HOME']}/Library/LaunchAgents/$_label.plist';

  const LaunchdService({ProcessRunner runner = const ProcessRunner()})
      : _runner = runner;

  String get label => _label;

  /// Returns true if the launchd job is currently loaded.
  Future<bool> isLoaded() async {
    final result = await _runner.run(
      'launchctl', ['list'],
      workingDirectory: '/',
    );
    return result.contains(_label);
  }

  /// Returns the current interval in minutes from the plist, or 0 if not found.
  Future<int> getInterval() async {
    final file = File(_plistPath);
    if (!file.existsSync()) return 0;
    final content = file.readAsStringSync();
    final match =
        RegExp(r'<key>StartInterval</key>\s*<integer>(\d+)</integer>')
            .firstMatch(content);
    if (match != null) {
      final seconds = int.tryParse(match.group(1)!) ?? 0;
      return (seconds / 60).round();
    }
    return 0;
  }

  /// Creates/updates the launchd plist with the given interval and scan dir.
  Future<void> install({
    required int intervalMinutes,
    required String scanDir,
    required String scriptPath,
  }) async {
    final seconds = intervalMinutes * 60;
    final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$scriptPath</string>
    <string>$scanDir</string>
  </array>
  <key>StartInterval</key>
  <integer>$seconds</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/$_label.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/$_label.err</string>
</dict>
</plist>
''';
    File(_plistPath).writeAsStringSync(plist);
  }

  /// Loads the launchd job.
  Future<void> load() async {
    await _runner.run(
      'launchctl', ['load', _plistPath],
      workingDirectory: '/',
    );
  }

  /// Unloads the launchd job.
  Future<void> unload() async {
    await _runner.run(
      'launchctl', ['unload', _plistPath],
      workingDirectory: '/',
    );
  }

  /// Force-runs the job immediately.
  Future<void> kick() async {
    await _runner.run(
      'launchctl', ['start', _label],
      workingDirectory: '/',
    );
  }
}
