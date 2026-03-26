import 'dart:io';
import '../models/repo_info.dart';
import 'process_runner.dart';

/// Scans a directory for git repositories and collects status information.
class RepoScanner {
  final ProcessRunner _runner;

  const RepoScanner({ProcessRunner runner = const ProcessRunner()})
      : _runner = runner;

  /// Scans [directory] for immediate subdirectories that are git repos.
  Future<List<RepoInfo>> scan(String directory) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return [];

    final repos = <RepoInfo>[];

    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final gitDir = Directory('${entity.path}/.git');
      if (!gitDir.existsSync()) continue;

      final repoPath = entity.path;
      final name = repoPath.split('/').last;

      final statusOutput = await _runner.run(
        'git', ['status', '--porcelain'],
        workingDirectory: repoPath,
      );
      final uncommitted = statusOutput.isEmpty
          ? 0
          : statusOutput.split('\n').where((l) => l.trim().isNotEmpty).length;

      final lastCommit = await _runner.run(
        'git', ['log', '-1', '--format=%ci'],
        workingDirectory: repoPath,
      );

      final branch = await _runner.run(
        'git', ['branch', '--show-current'],
        workingDirectory: repoPath,
      );

      final pushStatus = await _getPushStatus(repoPath);

      final prBranch = (branch.isNotEmpty &&
              branch != 'main' &&
              branch != 'master')
          ? branch
          : '';

      final openPR = await _getOpenPR(repoPath);
      final ciStatus = await _getCIStatus(repoPath);
      final ciDate = await _getCIDate(repoPath);

      repos.add(RepoInfo(
        name: name,
        folderModified: entity.statSync().modified,
        uncommittedCount: uncommitted,
        lastCommitDate: lastCommit,
        branch: branch,
        prBranch: prBranch,
        pushStatus: pushStatus,
        openPR: openPR,
        ciStatus: ciStatus,
        ciDate: ciDate,
      ));
    }

    repos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return repos;
  }

  Future<String> _getPushStatus(String repoPath) async {
    final upstream = await _runner.run(
      'git', ['rev-parse', '--abbrev-ref', '@{upstream}'],
      workingDirectory: repoPath,
    );
    if (upstream.isEmpty) return 'No upstream';

    final aheadBehind = await _runner.run(
      'git', ['rev-list', '--left-right', '--count', 'HEAD...@{upstream}'],
      workingDirectory: repoPath,
    );
    if (aheadBehind.isEmpty) return 'Unknown';

    final parts = aheadBehind.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final ahead = int.tryParse(parts[0]) ?? 0;
      final behind = int.tryParse(parts[1]) ?? 0;
      if (ahead == 0 && behind == 0) return 'Up to date';
      if (ahead > 0 && behind > 0) return 'Ahead $ahead / Behind $behind';
      if (ahead > 0) return 'Ahead $ahead';
      return 'Behind $behind';
    }
    return 'Unknown';
  }

  Future<String> _getOpenPR(String repoPath) async {
    final result = await _runner.run(
      'gh', ['pr', 'list', '--state=open', '--limit=1', '--json=number,title',
       '--jq=.[0].title // empty'],
      workingDirectory: repoPath,
    );
    return result;
  }

  Future<String> _getCIStatus(String repoPath) async {
    final result = await _runner.run(
      'gh', ['run', 'list', '--limit=1', '--json=status,conclusion',
       '--jq=.[0].conclusion // .[0].status // empty'],
      workingDirectory: repoPath,
    );
    return result.toUpperCase();
  }

  Future<String> _getCIDate(String repoPath) async {
    final result = await _runner.run(
      'gh', ['run', 'list', '--limit=1', '--json=updatedAt',
       '--jq=.[0].updatedAt // empty'],
      workingDirectory: repoPath,
    );
    return result;
  }
}
