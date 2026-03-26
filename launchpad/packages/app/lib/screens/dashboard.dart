import 'dart:async';

import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/job_table.dart';
import '../widgets/job_detail.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = LaunchdService();
  List<LaunchdJob> _allJobs = [];
  List<LaunchdJob> _filteredJobs = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Filters
  String _searchQuery = '';
  String _scopeFilter = 'all';
  String _statusFilter = 'all';
  String _sortColumn = 'label';
  bool _sortAscending = true;

  // Detail
  LaunchdJob? _selectedJob;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadJobs(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final jobs = await _service.listJobs();
      if (!mounted) return;
      setState(() {
        _allJobs = jobs;
        _loading = false;
        _error = null;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applyFilters() {
    var jobs = List<LaunchdJob>.from(_allJobs);

    // Scope
    if (_scopeFilter != 'all') {
      jobs = jobs.where((j) {
        return switch (_scopeFilter) {
          'user' => j.scope == JobScope.userAgent,
          'global' =>
            j.scope == JobScope.globalAgent || j.scope == JobScope.globalDaemon,
          'system' =>
            j.scope == JobScope.systemAgent || j.scope == JobScope.systemDaemon,
          _ => true,
        };
      }).toList();
    }

    // Status
    if (_statusFilter != 'all') {
      jobs = jobs.where((j) {
        return switch (_statusFilter) {
          'loaded' => j.isLoaded,
          'running' => j.status == JobStatus.running,
          'errored' =>  j.status == JobStatus.error,
          _ => true,
        };
      }).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      jobs = jobs.where((j) => j.label.toLowerCase().contains(q)).toList();
    }

    // Sort
    jobs.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 'label':
          cmp = a.label.compareTo(b.label);
        case 'status':
          cmp = a.status.index.compareTo(b.status.index);
        case 'pid':
          cmp = (a.pid ?? 0).compareTo(b.pid ?? 0);
        case 'exit':
          cmp = (a.lastExitStatus ?? -1).compareTo(b.lastExitStatus ?? -1);
        case 'schedule':
          cmp = a.scheduleDescription.compareTo(b.scheduleDescription);
        case 'path':
          cmp = a.path.compareTo(b.path);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });

    _filteredJobs = jobs;
  }

  Map<String, int> get _scopeCounts {
    int user = 0, global = 0, system = 0;
    for (final j in _allJobs) {
      switch (j.scope) {
        case JobScope.userAgent:
          user++;
        case JobScope.globalAgent:
        case JobScope.globalDaemon:
          global++;
        case JobScope.systemAgent:
        case JobScope.systemDaemon:
          system++;
      }
    }
    return {'user': user, 'global': global, 'system': system, 'all': _allJobs.length};
  }

  void _onScopeChanged(String scope) {
    setState(() {
      _scopeFilter = scope;
      _applyFilters();
    });
  }

  void _onStatusChanged(String status) {
    setState(() {
      _statusFilter = status;
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _applyFilters();
    });
  }

  void _onJobSelected(LaunchdJob job) {
    setState(() => _selectedJob = job);
  }

  void _onDetailClosed() {
    setState(() => _selectedJob = null);
  }

  Future<void> _onJobAction(String action, LaunchdJob job) async {
    try {
      switch (action) {
        case 'load':
          await _service.loadJob(job.path);
        case 'unload':
          await _service.unloadJob(job.path);
        case 'start':
          await _service.startJob(job.label);
        case 'stop':
          await _service.stopJob(job.label);
        case 'enable':
          await _service.enableJob(job.label);
        case 'disable':
          await _service.disableJob(job.label);
      }
      await _loadJobs(silent: true);
      // Refresh selected job detail
      if (_selectedJob?.label == job.label) {
        final updated = _allJobs.where((j) => j.label == job.label).firstOrNull;
        setState(() => _selectedJob = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Sidebar(
            scopeCounts: _scopeCounts,
            selectedScope: _scopeFilter,
            selectedStatus: _statusFilter,
            onScopeChanged: _onScopeChanged,
            onStatusChanged: _onStatusChanged,
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                _buildToolbar(),
                Container(height: 1, color: AppColors.border),
                Expanded(
                  child: _loading && _allJobs.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent))
                      : _error != null && _allJobs.isEmpty
                          ? Center(
                              child: Text('Error: $_error',
                                  style: const TextStyle(
                                      color: AppColors.error)))
                          : _selectedJob != null
                              ? JobDetail(
                                  job: _selectedJob!,
                                  service: _service,
                                  onClose: _onDetailClosed,
                                  onAction: _onJobAction,
                                  onRefresh: () => _loadJobs(silent: true),
                                )
                              : JobTable(
                                  jobs: _filteredJobs,
                                  sortColumn: _sortColumn,
                                  sortAscending: _sortAscending,
                                  onSort: _onSort,
                                  onJobSelected: _onJobSelected,
                                  onJobAction: _onJobAction,
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Text('Launchpad',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 24),
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppColors.text, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon:
                    Icon(Icons.search, color: AppColors.muted, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredJobs.length} jobs',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
                : const Icon(Icons.refresh, color: AppColors.muted, size: 18),
            onPressed: () => _loadJobs(),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}
