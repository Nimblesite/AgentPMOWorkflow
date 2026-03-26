import 'dart:io';

import 'package:launchpad_core/core.dart';
import 'package:args/command_runner.dart';

import '../ansi.dart';

class CreateCommand extends Command<void> {
  @override
  final name = 'create';
  @override
  final description = 'Create a new launchd job interactively';

  @override
  Future<void> run() async {
    stdout.writeln(Ansi.colorize('Create a new launchd job', Ansi.cyan));
    stdout.writeln();

    // Label
    stdout.write('Label (e.g. com.mycompany.myjob): ');
    final label = stdin.readLineSync()?.trim();
    if (label == null || label.isEmpty) {
      stderr.writeln('Label is required.');
      exit(1);
    }

    // Program
    stdout.write('Program/command (e.g. /usr/bin/python3): ');
    final program = stdin.readLineSync()?.trim() ?? '';

    // Arguments
    stdout.write('Arguments (space-separated, or empty): ');
    final argsLine = stdin.readLineSync()?.trim() ?? '';
    final args = argsLine.isEmpty ? <String>[] : argsLine.split(' ');

    // Interval
    stdout.write('Run interval in seconds (or empty for none): ');
    final intervalStr = stdin.readLineSync()?.trim() ?? '';
    final interval = int.tryParse(intervalStr);

    // Run at load
    stdout.write('Run at load? (y/n) [n]: ');
    final runAtLoadStr = stdin.readLineSync()?.trim().toLowerCase() ?? 'n';
    final runAtLoad = runAtLoadStr == 'y' || runAtLoadStr == 'yes';

    // Working directory
    stdout.write('Working directory (or empty): ');
    final workDir = stdin.readLineSync()?.trim() ?? '';

    // Build plist
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">');
    buf.writeln('<plist version="1.0">');
    buf.writeln('<dict>');
    buf.writeln('\t<key>Label</key>');
    buf.writeln('\t<string>$label</string>');

    buf.writeln('\t<key>ProgramArguments</key>');
    buf.writeln('\t<array>');
    if (program.isNotEmpty) buf.writeln('\t\t<string>$program</string>');
    for (final arg in args) {
      buf.writeln('\t\t<string>$arg</string>');
    }
    buf.writeln('\t</array>');

    if (interval != null) {
      buf.writeln('\t<key>StartInterval</key>');
      buf.writeln('\t<integer>$interval</integer>');
    }

    buf.writeln('\t<key>RunAtLoad</key>');
    buf.writeln(runAtLoad ? '\t<true/>' : '\t<false/>');

    if (workDir.isNotEmpty) {
      buf.writeln('\t<key>WorkingDirectory</key>');
      buf.writeln('\t<string>$workDir</string>');
    }

    buf.writeln('\t<key>StandardOutPath</key>');
    buf.writeln('\t<string>/tmp/$label.stdout.log</string>');
    buf.writeln('\t<key>StandardErrorPath</key>');
    buf.writeln('\t<string>/tmp/$label.stderr.log</string>');

    buf.writeln('</dict>');
    buf.writeln('</plist>');

    final content = buf.toString();
    stdout.writeln();
    stdout.writeln(Ansi.colorize('── Generated Plist ──', Ansi.cyan));
    stdout.writeln(content);

    // Confirm
    stdout.write('Save and load? (y/n) [y]: ');
    final confirm = stdin.readLineSync()?.trim().toLowerCase() ?? 'y';
    if (confirm != 'y' && confirm != 'yes' && confirm.isNotEmpty) {
      stdout.writeln('Cancelled.');
      return;
    }

    // Save
    final home = Platform.environment['HOME']!;
    final path = '$home/Library/LaunchAgents/$label.plist';
    final plistService = PlistService();
    await plistService.write(path, content);
    stdout.writeln(Ansi.colorize('Saved: $path', Ansi.green));

    // Load
    final result = await LaunchdService().loadJob(path);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Loaded successfully!', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize(
          'Saved but failed to load: ${result.stderr}', Ansi.yellow));
    }
  }
}
