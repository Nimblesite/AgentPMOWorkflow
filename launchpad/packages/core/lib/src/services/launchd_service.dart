import 'dart:io';

import '../models/launchd_job.dart';
import 'plist_service.dart';

class LaunchdService {
  final PlistService _plistService;

  LaunchdService({PlistService? plistService})
      : _plistService = plistService ?? PlistService();

  static const _plistDirectories = [
    '~/Library/LaunchAgents',
    '/Library/LaunchAgents',
    '/Library/LaunchDaemons',
    '/System/Library/LaunchAgents',
    '/System/Library/LaunchDaemons',
  ];

  /// List all jobs from all plist directories merged with runtime state.
  Future<List<LaunchdJob>> listJobs() async {
    final runtimeState = await _getLaunchctlList();
    final jobs = <LaunchdJob>[];

    for (final dirPath in _plistDirectories) {
      final expandedPath = _expandPath(dirPath);
      final dir = Directory(expandedPath);
      if (!await dir.exists()) continue;

      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.plist')) continue;
        try {
          final job = await _loadJobFromPlist(entity.path, runtimeState);
          jobs.add(job);
        } catch (_) {
          // Skip unreadable plists
        }
      }
    }

    // Sort by label
    jobs.sort((a, b) => a.label.compareTo(b.label));
    return jobs;
  }

  /// Get full details for a single job by label.
  Future<LaunchdJob?> getJobDetail(String label) async {
    final jobs = await listJobs();
    try {
      return jobs.firstWhere((j) => j.label == label);
    } catch (_) {
      return null;
    }
  }

  /// Load a job from its plist path.
  Future<ProcessResult> loadJob(String plistPath) async {
    final scope = JobScope.fromPath(plistPath);
    if (scope == JobScope.userAgent) {
      return Process.run('launchctl', ['load', plistPath]);
    } else {
      return Process.run('launchctl', ['load', '-w', plistPath]);
    }
  }

  /// Unload a job from its plist path.
  Future<ProcessResult> unloadJob(String plistPath) async {
    return Process.run('launchctl', ['unload', plistPath]);
  }

  /// Start (kick) a loaded job.
  Future<ProcessResult> startJob(String label) async {
    return Process.run('launchctl', ['start', label]);
  }

  /// Stop a running job.
  Future<ProcessResult> stopJob(String label) async {
    return Process.run('launchctl', ['stop', label]);
  }

  /// Enable a job by removing the disabled override.
  Future<ProcessResult> enableJob(String label) async {
    return Process.run(
        'launchctl', ['enable', 'gui/${_getUid()}/$label']);
  }

  /// Disable a job.
  Future<ProcessResult> disableJob(String label) async {
    return Process.run(
        'launchctl', ['disable', 'gui/${_getUid()}/$label']);
  }

  /// Read log tail from a file path.
  Future<String> getLog(String path, {int lines = 50}) async {
    final file = File(path);
    if (!await file.exists()) {
      return '(log file not found: $path)';
    }
    final result = await Process.run('tail', ['-n', '$lines', path]);
    return result.stdout as String;
  }

  /// Get the current user's UID for launchctl commands.
  String _getUid() {
    final result = Process.runSync('id', ['-u']);
    return (result.stdout as String).trim();
  }

  /// Expand ~ to home directory.
  String _expandPath(String path) {
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
      return '$home${path.substring(1)}';
    }
    return path;
  }

  /// Parse `launchctl list` output into a map of label -> {pid, status}.
  Future<Map<String, _RuntimeInfo>> _getLaunchctlList() async {
    final result = await Process.run('launchctl', ['list']);
    if (result.exitCode != 0) return {};

    final map = <String, _RuntimeInfo>{};
    final lines = (result.stdout as String).split('\n');

    for (final line in lines.skip(1)) {
      // Skip header
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) continue;

      final pidStr = parts[0];
      final statusStr = parts[1];
      final label = parts.sublist(2).join(' ');

      final pid = int.tryParse(pidStr);
      final status = int.tryParse(statusStr);

      map[label] = _RuntimeInfo(
        pid: pid,
        lastExitStatus: status,
        isLoaded: true,
      );
    }
    return map;
  }

  /// Load a single job from a plist file, merging with runtime state.
  Future<LaunchdJob> _loadJobFromPlist(
      String path, Map<String, _RuntimeInfo> runtimeState) async {
    final scope = JobScope.fromPath(path);
    final plistContent = await _plistService.read(path);

    Map<String, dynamic> parsed;
    try {
      parsed = await _plistService.parse(path);
    } catch (_) {
      // If we can't parse, create a minimal job
      final label = path.split('/').last.replaceAll('.plist', '');
      return LaunchdJob(
        label: label,
        path: path,
        scope: scope,
        plistContent: plistContent,
      );
    }

    final label = parsed['Label'] as String? ??
        path.split('/').last.replaceAll('.plist', '');
    final runtime = runtimeState[label];

    return LaunchdJob(
      label: label,
      path: path,
      scope: scope,
      isLoaded: runtime?.isLoaded ?? false,
      pid: runtime?.pid,
      lastExitStatus: runtime?.lastExitStatus,
      program: parsed['Program'] as String?,
      programArguments: (parsed['ProgramArguments'] as List<dynamic>?)
          ?.cast<String>(),
      startInterval: parsed['StartInterval'] as int?,
      startCalendarInterval:
          parsed['StartCalendarInterval'] as Map<String, dynamic>?,
      runAtLoad: parsed['RunAtLoad'] as bool? ?? false,
      keepAlive: parsed['KeepAlive'],
      standardOutPath: parsed['StandardOutPath'] as String?,
      standardErrorPath: parsed['StandardErrorPath'] as String?,
      workingDirectory: parsed['WorkingDirectory'] as String?,
      environmentVariables:
          (parsed['EnvironmentVariables'] as Map<String, dynamic>?)
              ?.cast<String, String>(),
      disabled: parsed['Disabled'] as bool? ?? false,
      plistContent: plistContent,
    );
  }
}

class _RuntimeInfo {
  final int? pid;
  final int? lastExitStatus;
  final bool isLoaded;

  _RuntimeInfo({this.pid, this.lastExitStatus, this.isLoaded = false});
}
