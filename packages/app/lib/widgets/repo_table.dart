import 'package:flutter/material.dart';
import 'package:project_status_core/core.dart';
import '../theme.dart';
import 'status_badge.dart';

/// Sort direction for table columns.
enum _SortDir { asc, desc }

class RepoTable extends StatefulWidget {
  final List<RepoInfo> repos;

  const RepoTable({super.key, required this.repos});

  @override
  State<RepoTable> createState() => _RepoTableState();
}

class _RepoTableState extends State<RepoTable> {
  int _sortColumn = 0;
  _SortDir _sortDir = _SortDir.asc;
  int? _hoveredRow;

  static const _columns = [
    'REPOSITORY',
    'UNCOMMITTED',
    'LAST COMMIT',
    'BRANCH',
    'PR BRANCH',
    'PUSH STATUS',
    'OPEN PR',
    'CI',
    'CI DATE',
  ];

  static const _flexValues = [3, 2, 3, 2, 2, 2, 3, 2, 3];

  List<RepoInfo> get _sortedRepos {
    final sorted = List<RepoInfo>.from(widget.repos);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 1:
          cmp = a.uncommittedCount.compareTo(b.uncommittedCount);
        case 2:
          cmp = a.lastCommitDate.compareTo(b.lastCommitDate);
        case 3:
          cmp = a.branch.compareTo(b.branch);
        case 4:
          cmp = a.prBranch.compareTo(b.prBranch);
        case 5:
          cmp = a.pushStatus.compareTo(b.pushStatus);
        case 6:
          cmp = a.openPR.compareTo(b.openPR);
        case 7:
          cmp = a.ciStatus.compareTo(b.ciStatus);
        case 8:
          cmp = a.ciDate.compareTo(b.ciDate);
        default:
          cmp = 0;
      }
      return _sortDir == _SortDir.asc ? cmp : -cmp;
    });
    return sorted;
  }

  void _onHeaderTap(int index) {
    setState(() {
      if (_sortColumn == index) {
        _sortDir =
            _sortDir == _SortDir.asc ? _SortDir.desc : _SortDir.asc;
      } else {
        _sortColumn = index;
        _sortDir = _SortDir.asc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repos = _sortedRepos;

    return Column(
      children: [
        // Header row
        Container(
          decoration: const BoxDecoration(
            color: AppColors.headerBg,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: List.generate(_columns.length, (i) {
              final isActive = _sortColumn == i;
              return Expanded(
                flex: _flexValues[i],
                child: GestureDetector(
                  onTap: () => _onHeaderTap(i),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _columns[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.accent
                                : AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _sortDir == _SortDir.asc
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 12,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: repos.length,
            itemBuilder: (context, index) {
              return _buildRow(repos[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(RepoInfo repo, int index) {
    final isHovered = _hoveredRow == index;
    final bgColor = isHovered
        ? AppColors.hoverRow
        : (index.isEven ? AppColors.surface : AppColors.surfaceAlt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = index),
      onExit: (_) => setState(() => _hoveredRow = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bgColor,
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Repository name
            Expanded(
              flex: _flexValues[0],
              child: Text(
                repo.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Uncommitted
            Expanded(
              flex: _flexValues[1],
              child: Text(
                repo.uncommittedCount.toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Menlo',
                  fontWeight: FontWeight.w600,
                  color: repo.uncommittedCount == 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ),
            // Last Commit
            Expanded(
              flex: _flexValues[2],
              child: Text(
                _formatDate(repo.lastCommitDate),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Branch
            Expanded(
              flex: _flexValues[3],
              child: BranchPill(branch: repo.branch),
            ),
            // PR Branch
            Expanded(
              flex: _flexValues[4],
              child: BranchPill(branch: repo.prBranch),
            ),
            // Push Status
            Expanded(
              flex: _flexValues[5],
              child: StatusBadge.push(repo.pushStatus),
            ),
            // Open PR
            Expanded(
              flex: _flexValues[6],
              child: Text(
                repo.openPR.isEmpty ? '-' : repo.openPR,
                style: TextStyle(
                  fontSize: 12,
                  color: repo.openPR.isEmpty
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // CI
            Expanded(
              flex: _flexValues[7],
              child: StatusBadge.ci(repo.ciStatus),
            ),
            // CI Date
            Expanded(
              flex: _flexValues[8],
              child: Text(
                _formatDate(repo.ciDate),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    // Try to parse and show a shorter form
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      // git format: "2024-01-15 10:30:00 +0000" – just trim timezone
      if (raw.length > 19) return raw.substring(0, 19);
      return raw;
    }
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
