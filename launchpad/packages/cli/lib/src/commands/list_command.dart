import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_core/core.dart';

import '../ansi.dart';
import '../table.dart';

class ListCommand extends Command<void> {
  @override
  final name = 'list';

  @override
  final description = 'List launchd jobs';

  ListCommand() {
    argParser
      ..addOption('scope',
          abbr: 's',
          help: 'Filter by scope',
          allowed: ['all', 'user', 'global', 'system'],
          defaultsTo: 'all')
      ..addFlag('loaded', help: 'Only loaded jobs', negatable: false)
      ..addFlag('running', help: 'Only running jobs', negatable: false)
      ..addOption('filter',
          abbr: 'f', help: 'Filter by label (substring match)');
  }

  @override
  Future<void> run() async {
    final service = LaunchdService();
    var jobs = await service.listJobs();

    // Apply scope filter
    final scope = argResults!['scope'] as String;
    if (scope != 'all') {
      jobs = jobs.where((j) {
        return switch (scope) {
          'user' => j.scope == JobScope.userAgent,
          'global' =>
            j.scope == JobScope.globalAgent || j.scope == JobScope.globalDaemon,
          'system' =>
            j.scope == JobScope.systemAgent || j.scope == JobScope.systemDaemon,
          _ => true,
        };
      }).toList();
    }

    // Apply status filters
    if (argResults!['loaded'] as bool) {
      jobs = jobs.where((j) => j.isLoaded).toList();
    }
    if (argResults!['running'] as bool) {
      jobs = jobs.where((j) => j.status == JobStatus.running).toList();
    }

    // Apply label filter
    final filter = argResults!['filter'] as String?;
    if (filter != null && filter.isNotEmpty) {
      final lower = filter.toLowerCase();
      jobs = jobs.where((j) => j.label.toLowerCase().contains(lower)).toList();
    }

    final table = Table(
      headers: ['Label', 'Status', 'PID', 'Last Exit', 'Schedule', 'Path'],
      rows: jobs.map((j) {
        return [
          j.label,
          Ansi.statusColor(j.status.displayName),
          Ansi.pidDisplay(j.pid),
          Ansi.exitColor(j.lastExitStatus),
          j.scheduleDescription,
          j.path,
        ];
      }).toList(),
    );

    stdout.write(table.render());
    stdout.writeln(
        '\n${Ansi.colorize('${jobs.length} jobs', Ansi.cyan)}');
  }
}
