import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';
import 'status_badge.dart';

class JobTable extends StatelessWidget {
  final List<LaunchdJob> jobs;
  final String sortColumn;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final ValueChanged<LaunchdJob> onJobSelected;
  final Future<void> Function(String action, LaunchdJob job) onJobAction;

  const JobTable({
    super.key,
    required this.jobs,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onJobSelected,
    required this.onJobAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Container(height: 1, color: AppColors.border),
        Expanded(
          child: jobs.isEmpty
              ? const Center(
                  child: Text('No jobs found',
                      style: TextStyle(color: AppColors.muted)))
              : ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (ctx, i) => _buildRow(ctx, jobs[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 36,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _headerCell('Label', 'label', flex: 4),
          _headerCell('Status', 'status', flex: 2),
          _headerCell('PID', 'pid', flex: 1),
          _headerCell('Exit', 'exit', flex: 1),
          _headerCell('Schedule', 'schedule', flex: 2),
          _headerCell('Path', 'path', flex: 4),
        ],
      ),
    );
  }

  Widget _headerCell(String label, String column, {int flex = 1}) {
    final isActive = sortColumn == column;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(column),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.text : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: AppColors.text,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, LaunchdJob job, int index) {
    return Material(
      color: index.isEven ? AppColors.background : AppColors.surface.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => onJobSelected(job),
        hoverColor: AppColors.accent.withValues(alpha: 0.08),
        child: GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition, job),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Label
                Expanded(
                  flex: 4,
                  child: Text(
                    job.label,
                    style: AppTheme.monoStyle.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status
                Expanded(
                  flex: 2,
                  child: StatusBadge(status: job.status),
                ),
                // PID
                Expanded(
                  flex: 1,
                  child: Text(
                    job.pid != null && job.pid! > 0 ? '${job.pid}' : '-',
                    style: TextStyle(
                      color: job.pid != null && job.pid! > 0
                          ? AppColors.text
                          : AppColors.dimmed,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Exit
                Expanded(
                  flex: 1,
                  child: ExitBadge(exitStatus: job.lastExitStatus),
                ),
                // Schedule
                Expanded(
                  flex: 2,
                  child: Text(
                    job.scheduleDescription,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Path
                Expanded(
                  flex: 4,
                  child: Text(
                    job.path,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, Offset position, LaunchdJob job) {
    final items = <PopupMenuEntry<String>>[];

    if (job.isLoaded) {
      items.add(const PopupMenuItem(value: 'unload', child: Text('Unload')));
      if (job.status == JobStatus.running) {
        items.add(const PopupMenuItem(value: 'stop', child: Text('Stop')));
      } else {
        items.add(const PopupMenuItem(value: 'start', child: Text('Start')));
      }
    } else {
      items.add(const PopupMenuItem(value: 'load', child: Text('Load')));
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: items,
      color: AppColors.surface,
    ).then((action) {
      if (action != null) onJobAction(action, job);
    });
  }
}
