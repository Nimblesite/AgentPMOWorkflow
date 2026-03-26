import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final JobStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(JobStatus status) {
    return switch (status) {
      JobStatus.running => (AppColors.accent, AppColors.accent.withValues(alpha: 0.15)),
      JobStatus.loaded => (AppColors.success, AppColors.success.withValues(alpha: 0.15)),
      JobStatus.error => (AppColors.error, AppColors.error.withValues(alpha: 0.15)),
      JobStatus.notLoaded => (AppColors.dimmed, AppColors.dimmed.withValues(alpha: 0.15)),
    };
  }
}

class ExitBadge extends StatelessWidget {
  final int? exitStatus;

  const ExitBadge({super.key, this.exitStatus});

  @override
  Widget build(BuildContext context) {
    if (exitStatus == null) {
      return const Text('-',
          style: TextStyle(color: AppColors.dimmed, fontSize: 12));
    }

    final color = exitStatus == 0 ? AppColors.success : AppColors.error;
    return Text(
      '$exitStatus',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
    );
  }
}

class ScopeBadge extends StatelessWidget {
  final JobScope scope;

  const ScopeBadge({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final color = scope.isSystem
        ? AppColors.warning
        : scope.requiresRoot
            ? AppColors.accent
            : AppColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        scope.displayName,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
