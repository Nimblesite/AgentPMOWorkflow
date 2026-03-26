import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:project_status_core/core.dart';
import '../theme.dart';
import '../widgets/repo_table.dart';
import '../widgets/settings_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RepoScanner _scanner = const RepoScanner();
  final LaunchdService _launchd = const LaunchdService();

  List<RepoInfo> _repos = [];
  bool _loading = false;
  bool _settingsOpen = false;
  bool _launchdLoaded = false;
  int _intervalMinutes = 30;
  String _scanDirectory = '';
  DateTime? _lastScan;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Default scan directory
    _scanDirectory =
        Platform.environment['HOME'] ?? '/Users';
    _refresh();
    _loadLaunchdState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repos = await _scanner.scan(_scanDirectory);
      if (mounted) {
        setState(() {
          _repos = repos;
          _lastScan = DateTime.now();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLaunchdState() async {
    try {
      final loaded = await _launchd.isLoaded();
      final interval = await _launchd.getInterval();
      if (mounted) {
        setState(() {
          _launchdLoaded = loaded;
          if (interval > 0) _intervalMinutes = interval;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLaunchd() async {
    try {
      if (_launchdLoaded) {
        await _launchd.unload();
      } else {
        await _launchd.load();
      }
      await _loadLaunchdState();
    } catch (_) {}
  }

  Future<void> _kick() async {
    try {
      await _launchd.kick();
      // Refresh after a short delay to pick up new data
      Future.delayed(const Duration(seconds: 2), _refresh);
    } catch (_) {}
  }

  void _onScanDirectoryChanged(String dir) {
    setState(() => _scanDirectory = dir);
    _refresh();
  }

  void _onIntervalChanged(int minutes) {
    setState(() => _intervalMinutes = minutes);
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                // Loading indicator
                if (_loading)
                  LinearProgressIndicator(
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 2,
                  ),
                // Content
                Expanded(child: _buildContent()),
                _buildStatusBar(),
              ],
            ),
          ),
          // Settings panel
          if (_settingsOpen)
            SettingsPanel(
              scanDirectory: _scanDirectory,
              intervalMinutes: _intervalMinutes,
              launchdLoaded: _launchdLoaded,
              onScanDirectoryChanged: _onScanDirectoryChanged,
              onIntervalChanged: _onIntervalChanged,
              onToggleLaunchd: _toggleLaunchd,
              onKick: _kick,
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Project Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 16),
          if (_lastScan != null)
            Text(
              _formatTimestamp(_lastScan),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          const Spacer(),
          _iconButton(
            icon: _loading ? Icons.hourglass_empty : Icons.refresh,
            tooltip: 'Refresh',
            onTap: _loading ? null : _refresh,
          ),
          const SizedBox(width: 4),
          _iconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => setState(() => _settingsOpen = !_settingsOpen),
            active: _settingsOpen,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_loading && _repos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'No repositories found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your scan directory in settings',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    return RepoTable(repos: _repos);
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.headerBg,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _statusItem(
            icon: _launchdLoaded ? Icons.circle : Icons.circle_outlined,
            color: _launchdLoaded ? AppColors.success : AppColors.textMuted,
            label: _launchdLoaded ? 'launchd loaded' : 'launchd not loaded',
          ),
          const SizedBox(width: 24),
          _statusItem(
            icon: Icons.timer_outlined,
            color: AppColors.textMuted,
            label: '$_intervalMinutes min interval',
          ),
          const SizedBox(width: 24),
          _statusItem(
            icon: Icons.access_time,
            color: AppColors.textMuted,
            label: _lastScan != null
                ? 'Last scan: ${_formatTimestamp(_lastScan)}'
                : 'No scan yet',
          ),
          const Spacer(),
          Text(
            '${_repos.length} repositories',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor:
              onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
