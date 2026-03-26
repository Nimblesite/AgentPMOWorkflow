import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';

class CreateJobDialog extends StatefulWidget {
  final VoidCallback onCreated;

  const CreateJobDialog({super.key, required this.onCreated});

  @override
  State<CreateJobDialog> createState() => _CreateJobDialogState();

  static Future<void> show(BuildContext context, {required VoidCallback onCreated}) {
    return showDialog(
      context: context,
      builder: (ctx) => CreateJobDialog(onCreated: onCreated),
    );
  }
}

class _CreateJobDialogState extends State<CreateJobDialog> {
  final _labelController = TextEditingController();
  final _programController = TextEditingController();
  final _argsController = TextEditingController();
  final _intervalController = TextEditingController();
  final _workDirController = TextEditingController();
  final _stdoutController = TextEditingController();
  final _stderrController = TextEditingController();
  bool _runAtLoad = false;
  String? _error;
  bool _saving = false;

  String get _preview {
    final label = _labelController.text.trim();
    if (label.isEmpty) return '(enter a label to preview)';

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
    final prog = _programController.text.trim();
    if (prog.isNotEmpty) buf.writeln('\t\t<string>$prog</string>');
    final args = _argsController.text.trim();
    if (args.isNotEmpty) {
      for (final arg in args.split(' ')) {
        buf.writeln('\t\t<string>$arg</string>');
      }
    }
    buf.writeln('\t</array>');

    final interval = int.tryParse(_intervalController.text.trim());
    if (interval != null) {
      buf.writeln('\t<key>StartInterval</key>');
      buf.writeln('\t<integer>$interval</integer>');
    }

    buf.writeln('\t<key>RunAtLoad</key>');
    buf.writeln(_runAtLoad ? '\t<true/>' : '\t<false/>');

    final workDir = _workDirController.text.trim();
    if (workDir.isNotEmpty) {
      buf.writeln('\t<key>WorkingDirectory</key>');
      buf.writeln('\t<string>$workDir</string>');
    }

    final stdout = _stdoutController.text.trim();
    buf.writeln('\t<key>StandardOutPath</key>');
    buf.writeln(
        '\t<string>${stdout.isNotEmpty ? stdout : '/tmp/$label.stdout.log'}</string>');

    final stderr = _stderrController.text.trim();
    buf.writeln('\t<key>StandardErrorPath</key>');
    buf.writeln(
        '\t<string>${stderr.isNotEmpty ? stderr : '/tmp/$label.stderr.log'}</string>');

    buf.writeln('</dict>');
    buf.writeln('</plist>');
    return buf.toString();
  }

  Future<void> _create() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final content = _preview;
      final home = Platform.environment['HOME']!;
      final path = '$home/Library/LaunchAgents/$label.plist';

      final plistService = PlistService();
      final errors = await plistService.validate(content);
      if (errors.isNotEmpty) {
        setState(() {
          _error = errors.join('\n');
          _saving = false;
        });
        return;
      }

      await plistService.write(path, content);
      await LaunchdService().loadJob(path);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _programController.dispose();
    _argsController.dispose();
    _intervalController.dispose();
    _workDirController.dispose();
    _stdoutController.dispose();
    _stderrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text('Create New Job',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.muted, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Label *', _labelController,
                        hint: 'com.mycompany.myjob'),
                    _field('Program', _programController,
                        hint: '/usr/bin/python3'),
                    _field('Arguments', _argsController,
                        hint: 'script.py --verbose'),
                    _field('Interval (seconds)', _intervalController,
                        hint: '300'),
                    Row(
                      children: [
                        Checkbox(
                          value: _runAtLoad,
                          onChanged: (v) =>
                              setState(() => _runAtLoad = v ?? false),
                          activeColor: AppColors.accent,
                        ),
                        const Text('Run at load',
                            style: TextStyle(
                                color: AppColors.text, fontSize: 13)),
                      ],
                    ),
                    _field('Working directory', _workDirController,
                        hint: '/Users/you/project'),
                    _field('Stdout path', _stdoutController,
                        hint: '/tmp/myjob.stdout.log'),
                    _field('Stderr path', _stderrController,
                        hint: '/tmp/myjob.stderr.log'),

                    const SizedBox(height: 16),
                    const Text('Preview',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _preview,
                          style: AppTheme.monoStyle.copyWith(fontSize: 11),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Create & Load',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
