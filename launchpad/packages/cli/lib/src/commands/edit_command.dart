import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_core/core.dart';

import '../ansi.dart';

class EditCommand extends Command<void> {
  @override
  final name = 'edit';
  @override
  final description = 'Open a job\'s plist in \$EDITOR';
  @override
  String get invocation => '${runner!.executableName} edit <label>';

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

    if (job.scope.isSystem) {
      stderr.writeln(Ansi.colorize(
          'Cannot edit system job (SIP protected): $label', Ansi.red));
      exit(1);
    }

    final editor = Platform.environment['EDITOR'] ??
        Platform.environment['VISUAL'] ??
        'nano';

    stdout.writeln('Opening ${job.path} in $editor...');
    final result = await Process.start(editor, [job.path],
        mode: ProcessStartMode.inheritStdio);
    final exitCode = await result.exitCode;
    if (exitCode != 0) {
      stderr.writeln(Ansi.colorize('Editor exited with code $exitCode', Ansi.red));
    }
  }
}
