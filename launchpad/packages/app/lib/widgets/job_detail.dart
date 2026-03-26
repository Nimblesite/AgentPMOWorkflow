import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';
import 'status_badge.dart';
import 'log_viewer.dart';
import 'plist_editor.dart';

class JobDetail extends StatefulWidget {
  final LaunchdJob job;
  final LaunchdService service;
  final VoidCallback onClose;
  final Future<void> Function(String action, LaunchdJob job) onAction;
  final VoidCallback onRefresh;

  const JobDetail({
    super.key,
    required this.job,
    required this.service,
    required this.onClose,
    required this.onAction,
    required this.onRefresh,
  });

  @override
  State<JobDetail> createState() => _JobDetailState();
}

class _JobDetailState extends State<JobDetail> {
  bool _showPlist = false;
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final isSystem = job.scope.isSystem;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.muted, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Back to list',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.label,
                    style: AppTheme.monoStyle.copyWith(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                ScopeBadge(scope: job.scope),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row
                  Row(
                    children: [
                      StatusBadge(status: job.status),
                      const SizedBox(width: 16),
                      _infoChip('PID',
                          job.pid != null && job.pid! > 0 ? '${job.pid}' : '-'),
                      const SizedBox(width: 16),
                      _infoChip('Exit',
                          job.lastExitStatus?.toString() ?? '-',
                          color: job.lastExitStatus == null
                              ? null
                              : job.lastExitStatus == 0
                                  ? AppColors.success
                                  : AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Schedule
                  _section('Schedule', [
                    _detailRow('Schedule', job.scheduleDescription),
                    _detailRow('RunAtLoad', '${job.runAtLoad}'),
                    if (job.keepAlive != null)
                      _detailRow('KeepAlive', '${job.keepAlive}'),
                    if (job.disabled)
                      _detailRow('Disabled', 'true',
                          valueColor: AppColors.warning),
                  ]),

                  // Command
                  _section('Command', [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        job.command.isEmpty ? '(none)' : job.command,
                        style: AppTheme.monoStyle,
                      ),
                    ),
                  ]),

                  // Paths
                  _section('Paths', [
                    _detailRow(
                        'Working Dir', job.workingDirectory ?? '-'),
                    _detailRow('Stdout', job.standardOutPath ?? '-'),
                    _detailRow('Stderr', job.standardErrorPath ?? '-'),
                  ]),

                  // Environment
                  if (job.environmentVariables != null &&
                      job.environmentVariables!.isNotEmpty)
                    _section('Environment', [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: job.environmentVariables!.entries
                              .map((e) => Text(
                                    '${e.key}=${e.value}',
                                    style: AppTheme.monoStyle,
                                  ))
                              .toList(),
                        ),
                      ),
                    ]),

                  // Log preview
                  if (job.standardOutPath != null ||
                      job.standardErrorPath != null)
                    _section('Log Preview', [
                      LogViewer(
                        service: widget.service,
                        stdoutPath: job.standardOutPath,
                        stderrPath: job.standardErrorPath,
                      ),
                    ]),

                  // Raw plist
                  _section('Raw Plist', [
                    InkWell(
                      onTap: () => setState(() => _showPlist = !_showPlist),
                      child: Row(
                        children: [
                          Icon(
                            _showPlist
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppColors.muted,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showPlist ? 'Hide' : 'Show XML',
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_showPlist) ...[
                      const SizedBox(height: 8),
                      if (_editing)
                        PlistEditor(
                          content: job.plistContent,
                          path: job.path,
                          onSaved: () {
                            setState(() => _editing = false);
                            widget.onRefresh();
                          },
                          onCancel: () => setState(() => _editing = false),
                        )
                      else
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 400),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              job.plistContent,
                              style: AppTheme.monoStyle.copyWith(fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  ]),

                  const SizedBox(height: 24),

                  // Actions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (job.isLoaded)
                        _actionButton('Unload', Icons.eject, AppColors.warning,
                            () => _confirmAction('unload', job))
                      else
                        _actionButton('Load', Icons.play_arrow, AppColors.success,
                            () => widget.onAction('load', job)),
                      if (job.isLoaded && job.status != JobStatus.running)
                        _actionButton('Start', Icons.play_circle,
                            AppColors.accent, () => widget.onAction('start', job)),
                      if (job.status == JobStatus.running)
                        _actionButton('Stop', Icons.stop_circle, AppColors.error,
                            () => _confirmAction('stop', job)),
                      if (!isSystem) ...[
                        _actionButton('Edit', Icons.edit, AppColors.textSecondary,
                            () => setState(() => _editing = true)),
                        _actionButton(
                            'Delete',
                            Icons.delete,
                            AppColors.error,
                            () => _confirmDelete(job)),
                      ],
                    ],
                  ),

                  if (isSystem) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.lock, color: AppColors.warning, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'System job — read-only (SIP protected)',
                          style: TextStyle(
                              color: AppColors.warning, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor ?? AppColors.text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  color: color ?? AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Future<void> _confirmAction(String action, LaunchdJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Confirm $action',
            style: const TextStyle(color: AppColors.text)),
        content: Text('Are you sure you want to $action "${job.label}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action[0].toUpperCase() + action.substring(1),
                style: const TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onAction(action, job);
    }
  }

  Future<void> _confirmDelete(LaunchdJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Job',
            style: TextStyle(color: AppColors.error)),
        content: Text(
            'This will permanently delete the plist file:\n${job.path}\n\nThis cannot be undone.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (job.isLoaded) {
        await widget.service.unloadJob(job.path);
      }
      final file = File(job.path);
      if (await file.exists()) {
        await file.delete();
      }
      widget.onClose();
      widget.onRefresh();
    }
  }
}
