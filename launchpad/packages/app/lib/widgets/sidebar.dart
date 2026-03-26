import 'package:flutter/material.dart';

import '../theme.dart';

class Sidebar extends StatelessWidget {
  final Map<String, int> scopeCounts;
  final String selectedScope;
  final String selectedStatus;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String> onStatusChanged;

  const Sidebar({
    super.key,
    required this.scopeCounts,
    required this.selectedScope,
    required this.selectedStatus,
    required this.onScopeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _sectionHeader('SCOPES'),
          _scopeItem('All', 'all', scopeCounts['all'] ?? 0),
          _scopeItem('User', 'user', scopeCounts['user'] ?? 0),
          _scopeItem('Global', 'global', scopeCounts['global'] ?? 0),
          _scopeItem('System', 'system', scopeCounts['system'] ?? 0),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _sectionHeader('FILTERS'),
          _statusItem('All', 'all'),
          _statusItem('Loaded', 'loaded'),
          _statusItem('Running', 'running'),
          _statusItem('Errored', 'errored'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Launchpad v0.1.0',
              style: TextStyle(
                  color: AppColors.dimmed,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _scopeItem(String label, String value, int count) {
    final selected = selectedScope == value;
    return _navItem(
      label: label,
      trailing: '$count',
      selected: selected,
      onTap: () => onScopeChanged(value),
    );
  }

  Widget _statusItem(String label, String value) {
    final selected = selectedStatus == value;
    return _navItem(
      label: label,
      icon: switch (value) {
        'loaded' => Icons.check_circle_outline,
        'running' => Icons.play_circle_outline,
        'errored' => Icons.error_outline,
        _ => Icons.list,
      },
      selected: selected,
      onTap: () => onStatusChanged(value),
    );
  }

  Widget _navItem({
    required String label,
    IconData? icon,
    String? trailing,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceLight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected ? AppColors.accent : AppColors.muted),
                const SizedBox(width: 8),
              ],
              if (selected)
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trailing,
                    style: TextStyle(
                      color: selected ? AppColors.accent : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
