import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';

class LogViewer extends StatefulWidget {
  final LaunchdService service;
  final String? stdoutPath;
  final String? stderrPath;

  const LogViewer({
    super.key,
    required this.service,
    this.stdoutPath,
    this.stderrPath,
  });

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  String _logContent = '';
  bool _loading = true;
  bool _showStderr = false;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  @override
  void didUpdateWidget(LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stdoutPath != widget.stdoutPath ||
        oldWidget.stderrPath != widget.stderrPath) {
      _loadLog();
    }
  }

  Future<void> _loadLog() async {
    setState(() => _loading = true);
    try {
      final path = _showStderr
          ? widget.stderrPath
          : widget.stdoutPath ?? widget.stderrPath;
      if (path == null) {
        setState(() {
          _logContent = '(no log path configured)';
          _loading = false;
        });
        return;
      }
      final content = await widget.service.getLog(path, lines: 50);
      if (!mounted) return;
      setState(() {
        _logContent = content.isEmpty ? '(empty log)' : content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logContent = 'Error reading log: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar for stdout/stderr
        if (widget.stdoutPath != null && widget.stderrPath != null)
          Row(
            children: [
              _logTab('stdout', !_showStderr),
              const SizedBox(width: 8),
              _logTab('stderr', _showStderr),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 14, color: AppColors.muted),
                onPressed: _loadLog,
                tooltip: 'Refresh logs',
              ),
            ],
          ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                )
              : SingleChildScrollView(
                  child: SelectableText(
                    _logContent,
                    style: AppTheme.monoStyle.copyWith(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _logTab(String label, bool active) {
    return InkWell(
      onTap: () {
        setState(() => _showStderr = label == 'stderr');
        _loadLog();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent : AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
