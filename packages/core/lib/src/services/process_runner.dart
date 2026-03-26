import 'dart:io';

/// A callback for logging command execution details.
typedef LogCallback = void Function(String message);

/// Wraps [Process.run] with path resolution and error handling.
class ProcessRunner {
  final LogCallback? _log;

  /// Known directories to search when resolving command paths.
  static const _searchPaths = [
    '/opt/homebrew/bin',
    '/usr/local/bin',
    '/usr/bin',
    '/bin',
  ];

  const ProcessRunner({LogCallback? log}) : _log = log;

  /// Resolves [command] to an absolute path by checking [_searchPaths].
  ///
  /// Returns [command] unchanged if it is already absolute or if no match is
  /// found in the search paths.
  String resolveCommand(String command) {
    if (command.startsWith('/')) return command;

    for (final dir in _searchPaths) {
      final candidate = '$dir/$command';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    // Fall back to the bare command name and let the OS resolve it.
    return command;
  }

  /// Runs [command] with [args] inside [workingDirectory].
  ///
  /// Returns trimmed stdout on success (exit code 0) or an empty string on
  /// failure. Errors (e.g. command not found) are caught and logged.
  Future<String> run(
    String command,
    List<String> args, {
    required String workingDirectory,
  }) async {
    final resolved = resolveCommand(command);
    _log?.call('> $resolved ${args.join(' ')}  [cwd: $workingDirectory]');

    try {
      final result = await Process.run(
        resolved,
        args,
        workingDirectory: workingDirectory,
      );

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (result.exitCode != 0) {
        _log?.call('  exit ${result.exitCode}: $stderr');
        return '';
      }

      _log?.call('  -> $stdout');
      return stdout;
    } catch (e) {
      _log?.call('  error: $e');
      return '';
    }
  }
}
