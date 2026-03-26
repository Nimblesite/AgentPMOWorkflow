import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_core/core.dart';

class LogCommand extends Command<void> {
  @override
  final name = 'log';

  @override
  final description = 'View stdout/stderr logs for a job';

  @override
  String get invocation => '${runner!.executableName} log <label>';

  LogCommand() {
    argParser
      ..addFlag('follow',
          abbr: 'f', help: 'Follow log output', negatable: false)
      ..addOption('lines',
          abbr: 'n', help: 'Number of lines to show', defaultsTo: '50');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }

    final label = argResults!.rest.first;
    final follow = argResults!['follow'] as bool;
    final lines = int.tryParse(argResults!['lines'] as String) ?? 50;

    final service = LaunchdService();
    final job = await service.getJobDetail(label);

    if (job == null) {
      stderr.writeln('Job not found: $label');
      exit(1);
    }

    final logPaths = <String>[];
    if (job.standardOutPath != null) logPaths.add(job.standardOutPath!);
    if (job.standardErrorPath != null &&
        job.standardErrorPath != job.standardOutPath) {
      logPaths.add(job.standardErrorPath!);
    }

    if (logPaths.isEmpty) {
      stderr.writeln('No log paths configured for $label');
      exit(1);
    }

    if (follow) {
      // Use tail -f for follow mode
      final args = ['-f', '-n', '$lines', ...logPaths];
      final process = await Process.start('tail', args);
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);
      await process.exitCode;
    } else {
      for (final path in logPaths) {
        if (logPaths.length > 1) {
          stdout.writeln('==> $path <==');
        }
        final content = await service.getLog(path, lines: lines);
        stdout.write(content);
      }
    }
  }
}
