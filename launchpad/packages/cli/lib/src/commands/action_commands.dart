import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_core/core.dart';

import '../ansi.dart';

class LoadCommand extends Command<void> {
  @override
  final name = 'load';
  @override
  final description = 'Load a job from its plist path';
  @override
  String get invocation => '${runner!.executableName} load <plist-path>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a plist path.');
    }
    final path = argResults!.rest.first;
    final result = await LaunchdService().loadJob(path);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Loaded: $path', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to load: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}

class UnloadCommand extends Command<void> {
  @override
  final name = 'unload';
  @override
  final description = 'Unload a job from its plist path';
  @override
  String get invocation => '${runner!.executableName} unload <plist-path>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a plist path.');
    }
    final path = argResults!.rest.first;
    final result = await LaunchdService().unloadJob(path);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Unloaded: $path', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to unload: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}

class StartCommand extends Command<void> {
  @override
  final name = 'start';
  @override
  final description = 'Start (kick) a loaded job';
  @override
  String get invocation => '${runner!.executableName} start <label>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }
    final label = argResults!.rest.first;
    final result = await LaunchdService().startJob(label);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Started: $label', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to start: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}

class StopCommand extends Command<void> {
  @override
  final name = 'stop';
  @override
  final description = 'Stop a running job';
  @override
  String get invocation => '${runner!.executableName} stop <label>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }
    final label = argResults!.rest.first;
    final result = await LaunchdService().stopJob(label);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Stopped: $label', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to stop: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}

class EnableCommand extends Command<void> {
  @override
  final name = 'enable';
  @override
  final description = 'Enable a disabled job';
  @override
  String get invocation => '${runner!.executableName} enable <label>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }
    final label = argResults!.rest.first;
    final result = await LaunchdService().enableJob(label);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Enabled: $label', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to enable: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}

class DisableCommand extends Command<void> {
  @override
  final name = 'disable';
  @override
  final description = 'Disable a job';
  @override
  String get invocation => '${runner!.executableName} disable <label>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Please provide a job label.');
    }
    final label = argResults!.rest.first;
    final result = await LaunchdService().disableJob(label);
    if (result.exitCode == 0) {
      stdout.writeln(Ansi.colorize('Disabled: $label', Ansi.green));
    } else {
      stderr.writeln(Ansi.colorize('Failed to disable: ${result.stderr}', Ansi.red));
      exit(1);
    }
  }
}
