import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_core/core.dart';

import '../ansi.dart';

class InfoCommand extends Command<void> {
  @override
  final name = 'info';

  @override
  final description = 'Show full details for a job';

  @override
  String get invocation => '${runner!.executableName} info <label>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }

    final label = argResults!.rest.first;
    final service = LaunchdService();
    final job = await service.getJobDetail(label);

    if (job == null) {
      stderr.writeln('Job not found: $label');
      exit(1);
    }

    final buf = StringBuffer();
    buf.writeln(Ansi.colorize(Ansi.bold, Ansi.white) + job.label + Ansi.reset);
    buf.writeln();
    buf.writeln('${Ansi.colorize('Status:', Ansi.gray)}  ${Ansi.statusColor(job.status.displayName)}');
    buf.writeln('${Ansi.colorize('PID:', Ansi.gray)}     ${Ansi.pidDisplay(job.pid)}');
    buf.writeln('${Ansi.colorize('Exit:', Ansi.gray)}    ${Ansi.exitColor(job.lastExitStatus)}');
    buf.writeln('${Ansi.colorize('Scope:', Ansi.gray)}   ${job.scope.displayName}');
    buf.writeln('${Ansi.colorize('Path:', Ansi.gray)}    ${job.path}');
    buf.writeln();

    // Schedule
    buf.writeln(Ansi.colorize('── Schedule ──', Ansi.cyan));
    buf.writeln('Schedule:    ${job.scheduleDescription}');
    buf.writeln('RunAtLoad:   ${job.runAtLoad}');
    if (job.keepAlive != null) {
      buf.writeln('KeepAlive:   ${job.keepAlive}');
    }
    buf.writeln();

    // Command
    buf.writeln(Ansi.colorize('── Command ──', Ansi.cyan));
    buf.writeln(job.command.isEmpty ? '(none)' : job.command);
    buf.writeln();

    // Paths
    buf.writeln(Ansi.colorize('── Paths ──', Ansi.cyan));
    buf.writeln('Working Dir: ${job.workingDirectory ?? '-'}');
    buf.writeln('Stdout:      ${job.standardOutPath ?? '-'}');
    buf.writeln('Stderr:      ${job.standardErrorPath ?? '-'}');
    buf.writeln();

    // Environment
    if (job.environmentVariables != null &&
        job.environmentVariables!.isNotEmpty) {
      buf.writeln(Ansi.colorize('── Environment ──', Ansi.cyan));
      for (final entry in job.environmentVariables!.entries) {
        buf.writeln('${entry.key}=${entry.value}');
      }
      buf.writeln();
    }

    // Disabled
    if (job.disabled) {
      buf.writeln(Ansi.colorize('⚠ Job is disabled', Ansi.yellow));
      buf.writeln();
    }

    // System job notice
    if (job.scope.isSystem) {
      buf.writeln(Ansi.colorize('🔒 System job (read-only, SIP protected)', Ansi.yellow));
    }

    stdout.write(buf);
  }
}
