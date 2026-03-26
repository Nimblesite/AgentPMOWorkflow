import 'dart:io';

import 'package:project_status_core/core.dart';

// ---------------------------------------------------------------------------
// ANSI helpers
// ---------------------------------------------------------------------------

const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _white = '\x1B[37m';
const _bgDarkGrey = '\x1B[48;5;236m';

// ---------------------------------------------------------------------------
// Table rendering
// ---------------------------------------------------------------------------

class _Column {
  final String header;
  final int maxWidth;
  final String Function(RepoInfo) extract;
  final String Function(RepoInfo)? colorize;

  const _Column({
    required this.header,
    required this.extract,
    this.maxWidth = 40,
    this.colorize,
  });
}

String _truncate(String s, int max) {
  if (s.length <= max) return s;
  return '${s.substring(0, max - 1)}\u2026';
}

String _pad(String s, int width) {
  if (s.length >= width) return s;
  return s + ' ' * (width - s.length);
}

int _visibleLength(String s) {
  return s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;
}

String _padAnsi(String s, int width) {
  final visible = _visibleLength(s);
  if (visible >= width) return s;
  return s + ' ' * (width - visible);
}

String _colorUncommitted(RepoInfo r) {
  final count = r.uncommittedCount;
  final text = count.toString();
  return count == 0 ? '$_green$text$_reset' : '$_red$_bold$text$_reset';
}

String _colorPushStatus(RepoInfo r) {
  final s = r.pushStatus;
  if (s == 'Up to date') return '$_green$s$_reset';
  return '$_yellow$s$_reset';
}

String _colorCI(RepoInfo r) {
  final s = r.ciStatus;
  if (s.isEmpty) return '';
  final upper = s.toUpperCase();
  if (upper == 'SUCCESS') return '$_green$s$_reset';
  if (upper == 'FAILURE' || upper == 'SKIPPED' || upper == 'CANCELLED' ||
      upper == 'ERROR' || upper == 'STARTUP_FAILURE') {
    return '$_red$s$_reset';
  }
  if (upper == 'IN_PROGRESS' || upper == 'PENDING' || upper == 'QUEUED') {
    return '$_yellow$s$_reset';
  }
  return s;
}

void _printTable(List<RepoInfo> repos) {
  final columns = <_Column>[
    _Column(header: 'Repository', extract: (r) => r.name, maxWidth: 30),
    _Column(
      header: 'Uncommitted',
      extract: (r) => r.uncommittedCount.toString(),
      maxWidth: 12,
      colorize: (r) => _colorUncommitted(r),
    ),
    _Column(
      header: 'Last Commit',
      extract: (r) => r.lastCommitDate.length >= 10
          ? r.lastCommitDate.substring(0, 10)
          : r.lastCommitDate,
      maxWidth: 12,
    ),
    _Column(header: 'Branch', extract: (r) => r.branch, maxWidth: 24),
    _Column(header: 'PR Branch', extract: (r) => r.prBranch, maxWidth: 24),
    _Column(
      header: 'Push Status',
      extract: (r) => r.pushStatus,
      maxWidth: 22,
      colorize: (r) => _colorPushStatus(r),
    ),
    _Column(header: 'Open PR', extract: (r) => r.openPR, maxWidth: 36),
    _Column(
      header: 'CI',
      extract: (r) => r.ciStatus,
      maxWidth: 16,
      colorize: (r) => _colorCI(r),
    ),
    _Column(header: 'CI Date', extract: (r) => r.ciDate, maxWidth: 18),
  ];

  // Compute column widths based on content.
  final widths = <int>[];
  for (final col in columns) {
    var w = col.header.length;
    for (final repo in repos) {
      final cell = _truncate(col.extract(repo), col.maxWidth);
      if (cell.length > w) w = cell.length;
    }
    if (w > col.maxWidth) w = col.maxWidth;
    widths.add(w);
  }

  // Build border segments.
  final sepParts = <String>[];
  for (final w in widths) {
    sepParts.add('\u2500' * (w + 2));
  }
  final topBorder = '\u250C${sepParts.join('\u252C')}\u2510';
  final separator = '\u251C${sepParts.join('\u253C')}\u2524';
  final bottomBorder = '\u2514${sepParts.join('\u2534')}\u2518';

  // Header row.
  final headerCells = <String>[];
  for (var i = 0; i < columns.length; i++) {
    headerCells.add(
      ' $_bold$_white${_pad(columns[i].header, widths[i])}$_reset ',
    );
  }
  stdout.writeln(topBorder);
  stdout.writeln(
    '\u2502$_bgDarkGrey${headerCells.join('$_reset\u2502$_bgDarkGrey')}$_reset\u2502',
  );
  stdout.writeln(separator);

  // Data rows.
  for (var ri = 0; ri < repos.length; ri++) {
    final repo = repos[ri];
    final cells = <String>[];
    for (var ci = 0; ci < columns.length; ci++) {
      final col = columns[ci];
      final raw = _truncate(col.extract(repo), col.maxWidth);
      if (col.colorize != null) {
        final colored = _truncateColored(
          col.colorize!(repo),
          raw,
          col.maxWidth,
        );
        cells.add(' ${_padAnsi(colored, widths[ci])} ');
      } else {
        cells.add(' ${_pad(raw, widths[ci])} ');
      }
    }
    stdout.writeln('\u2502${cells.join('\u2502')}\u2502');

    if (ri < repos.length - 1) {
      stdout.writeln(separator);
    }
  }

  stdout.writeln(bottomBorder);
}

/// Truncates a colored string by using the pre-truncated raw value
/// and re-applying the color function if needed.
String _truncateColored(String colored, String rawTruncated, int maxWidth) {
  // If the visible text fits, return as-is.
  if (_visibleLength(colored) <= maxWidth) return colored;
  // Otherwise, the raw version is already truncated; we just need to make
  // sure the ANSI codes wrap the truncated text. Since our colorize functions
  // produce the full text inside codes, we just return the colored version
  // as the table width will handle padding.
  return colored;
}

// ---------------------------------------------------------------------------
// Progress-aware scanning
// ---------------------------------------------------------------------------

/// Discovers git repo directories under [parentDir] and scans them one by one,
/// printing each repo name as it is scanned.
Future<List<RepoInfo>> _scanWithProgress(String parentDir) async {
  final parent = Directory(parentDir);
  if (!parent.existsSync()) {
    stderr.writeln('${_red}Directory does not exist: $parentDir$_reset');
    return [];
  }

  // Find git repos.
  final repoDirs = <Directory>[];
  for (final entity in parent.listSync(followLinks: false)) {
    if (entity is Directory &&
        Directory('${entity.path}/.git').existsSync()) {
      repoDirs.add(entity);
    }
  }

  if (repoDirs.isEmpty) return [];

  // Sort by modification time descending and take top 20.
  repoDirs.sort((a, b) {
    final aTime = a.statSync().modified;
    final bTime = b.statSync().modified;
    return bTime.compareTo(aTime);
  });
  final dirs = repoDirs.take(20).toList();

  stdout.writeln(
    '${_dim}Found ${dirs.length} git repositories (of ${repoDirs.length} total)$_reset',
  );
  stdout.writeln('');

  // Scan each repo individually so we can show progress.
  // We create a temporary directory containing only one repo symlink,
  // but it's simpler to just use the full scanner on the parent and
  // accept batch results. Since the core API scans all at once, we
  // show the directory names we found as a progress indicator, then scan.
  for (final dir in dirs) {
    final name = dir.path.split('/').last;
    stdout.write('  ${_dim}Scanning $name...$_reset\r');
  }

  // Clear progress line.
  stdout.write('${' ' * 60}\r');

  final scanner = RepoScanner();
  final repos = await scanner.scan(parentDir);

  // Print scanned repo names.
  for (final repo in repos) {
    stdout.writeln('  ${_dim}\u2713 ${repo.name}$_reset');
  }

  return repos;
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

Future<void> _runStatus(String parentDir) async {
  stdout.writeln('${_cyan}Scanning repos in:$_reset $parentDir');
  stdout.writeln('');

  final repos = await _scanWithProgress(parentDir);

  if (repos.isEmpty) {
    stdout.writeln('${_yellow}No git repositories found.$_reset');
    return;
  }

  // Sort by folder modified descending.
  repos.sort((a, b) => b.folderModified.compareTo(a.folderModified));

  stdout.writeln('');
  stdout.writeln(
    '${_bold}${repos.length} repositories$_reset  '
    '${_dim}(${DateTime.now().toString().substring(0, 16)})$_reset',
  );
  stdout.writeln('');

  _printTable(repos);
  stdout.writeln('');
}

Future<void> _runLaunchdStatus() async {
  final service = LaunchdService();
  final loaded = await service.isLoaded();
  final intervalMinutes = await service.getInterval();

  stdout.writeln('${_bold}Launchd Job Status$_reset');
  stdout.writeln('');
  stdout.writeln(
    '  Label:    ${service.label}',
  );
  stdout.writeln(
    '  Loaded:   ${loaded ? '${_green}yes$_reset' : '${_red}no$_reset'}',
  );
  if (intervalMinutes > 0) {
    stdout.writeln(
      '  Interval: ${intervalMinutes * 60} seconds ($intervalMinutes minutes)',
    );
  } else {
    stdout.writeln('  Interval: ${_dim}(not configured)$_reset');
  }
  stdout.writeln('');
}

Future<void> _runLaunchdStart() async {
  stdout.writeln('Loading launchd job...');
  await LaunchdService().load();
  stdout.writeln('${_green}Done.$_reset');
}

Future<void> _runLaunchdStop() async {
  stdout.writeln('Unloading launchd job...');
  await LaunchdService().unload();
  stdout.writeln('${_green}Done.$_reset');
}

Future<void> _runLaunchdKick() async {
  stdout.writeln('Forcing immediate run...');
  await LaunchdService().kick();
  stdout.writeln('${_green}Done.$_reset');
}

Future<void> _runLaunchdInterval(String minutesArg) async {
  final minutes = int.tryParse(minutesArg);
  if (minutes == null || minutes <= 0) {
    stderr.writeln('${_red}Error: interval must be a positive integer.$_reset');
    exit(1);
  }

  stdout.writeln('Setting interval to $minutes minutes...');

  final service = LaunchdService();

  // Unload, reinstall with new interval, reload.
  final loaded = await service.isLoaded();
  if (loaded) {
    await service.unload();
  }

  // We need a script path and scan dir for install. Use sensible defaults.
  final defaultScanDir = Directory.current.parent.path;
  final defaultScript = Platform.script.toFilePath();

  await service.install(
    intervalMinutes: minutes,
    scanDir: defaultScanDir,
    scriptPath: defaultScript,
  );

  await service.load();
  stdout.writeln('${_green}Done.$_reset');
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

String _resolveParentDir(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--dir=')) {
      return arg.substring('--dir='.length);
    }
    if (arg == '--dir' && i + 1 < args.length) {
      return args[i + 1];
    }
  }

  // Default: parent of the current working directory.
  return Directory.current.parent.path;
}

void _printUsage() {
  stdout.writeln('${_bold}project_status_cli$_reset - View git repo status');
  stdout.writeln('');
  stdout.writeln('${_bold}Usage:$_reset');
  stdout.writeln(
    '  dart run project_status_cli [options]              '
    'Show repo status table',
  );
  stdout.writeln(
    '  dart run project_status_cli status [options]       '
    'Show repo status table',
  );
  stdout.writeln(
    '  dart run project_status_cli launchd status         '
    'Show launchd job info',
  );
  stdout.writeln(
    '  dart run project_status_cli launchd start          '
    'Load the launchd job',
  );
  stdout.writeln(
    '  dart run project_status_cli launchd stop           '
    'Unload the launchd job',
  );
  stdout.writeln(
    '  dart run project_status_cli launchd kick           '
    'Force immediate run',
  );
  stdout.writeln(
    '  dart run project_status_cli launchd interval <m>   '
    'Set interval in minutes',
  );
  stdout.writeln('');
  stdout.writeln('${_bold}Options:$_reset');
  stdout.writeln(
    '  --dir <path>    Directory to scan (default: parent of cwd)',
  );
  stdout.writeln('  --help          Show this help message');
  stdout.writeln('');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Collect positional arguments (skip --dir and its value).
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dir') {
      i++; // Skip the next arg (the value).
      continue;
    }
    if (args[i].startsWith('--')) continue;
    positional.add(args[i]);
  }

  final command = positional.isNotEmpty ? positional[0] : 'status';

  switch (command) {
    case 'status':
      await _runStatus(_resolveParentDir(args));

    case 'launchd':
      final subcommand = positional.length > 1 ? positional[1] : 'status';
      switch (subcommand) {
        case 'status':
          await _runLaunchdStatus();
        case 'start':
          await _runLaunchdStart();
        case 'stop':
          await _runLaunchdStop();
        case 'kick':
          await _runLaunchdKick();
        case 'interval':
          if (positional.length < 3) {
            stderr.writeln(
              '${_red}Error: please provide interval in minutes.$_reset',
            );
            stderr.writeln('  Usage: launchd interval <minutes>');
            exit(1);
          }
          await _runLaunchdInterval(positional[2]);
        default:
          stderr.writeln(
            '${_red}Unknown launchd subcommand: $subcommand$_reset',
          );
          _printUsage();
          exit(1);
      }

    default:
      stderr.writeln('${_red}Unknown command: $command$_reset');
      _printUsage();
      exit(1);
  }
}
