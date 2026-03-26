import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:launchpad_cli/src/commands/list_command.dart';
import 'package:launchpad_cli/src/commands/info_command.dart';
import 'package:launchpad_cli/src/commands/log_command.dart';
import 'package:launchpad_cli/src/commands/action_commands.dart';
import 'package:launchpad_cli/src/commands/edit_command.dart';
import 'package:launchpad_cli/src/commands/create_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner<void>(
    'launchpad',
    'macOS launchd job manager',
  )
    ..addCommand(ListCommand())
    ..addCommand(InfoCommand())
    ..addCommand(LogCommand())
    ..addCommand(LoadCommand())
    ..addCommand(UnloadCommand())
    ..addCommand(StartCommand())
    ..addCommand(StopCommand())
    ..addCommand(EnableCommand())
    ..addCommand(DisableCommand())
    ..addCommand(EditCommand())
    ..addCommand(CreateCommand());

  // Default to list when no command given
  final effectiveArgs = args.isEmpty ? ['list'] : args;

  try {
    await runner.run(effectiveArgs);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
