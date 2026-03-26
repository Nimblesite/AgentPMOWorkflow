import 'package:flutter/material.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  /// Creates a badge for CI status strings.
  factory StatusBadge.ci(String status) {
    final upper = status.toUpperCase().trim();
    final Color color;
    switch (upper) {
      case 'SUCCESS':
        color = AppColors.success;
      case 'FAILURE':
      case 'SKIPPED':
      case 'CANCELLED':
        color = AppColors.error;
      case 'IN_PROGRESS':
      case 'PENDING':
      case 'QUEUED':
        color = AppColors.warning;
      default:
        color = AppColors.textMuted;
    }
    return StatusBadge(label: upper.isEmpty ? '-' : upper, color: color);
  }

  /// Creates a badge for push status strings.
  factory StatusBadge.push(String status) {
    final Color color;
    if (status == 'Up to date') {
      color = AppColors.success;
    } else if (status == 'No upstream') {
      color = AppColors.warning;
    } else if (status.contains('Ahead') || status.contains('Behind')) {
      color = AppColors.warning;
    } else {
      color = AppColors.textMuted;
    }
    return StatusBadge(label: status.isEmpty ? '-' : status, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// A pill-shaped label for branch names, monospace.
class BranchPill extends StatelessWidget {
  final String branch;

  const BranchPill({super.key, required this.branch});

  @override
  Widget build(BuildContext context) {
    if (branch.isEmpty) {
      return Text('-', style: TextStyle(color: AppColors.textMuted, fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Text(
        branch,
        style: const TextStyle(
          fontFamily: 'Menlo',
          fontSize: 11,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
