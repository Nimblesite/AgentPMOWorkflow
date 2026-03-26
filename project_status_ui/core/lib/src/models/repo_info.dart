class RepoInfo {
  final String name;
  final DateTime folderModified;
  final int uncommittedCount;
  final String lastCommitDate;
  final String branch;
  final String prBranch;
  final String pushStatus;
  final String openPR;
  final String ciStatus;
  final String ciDate;

  const RepoInfo({
    required this.name,
    required this.folderModified,
    this.uncommittedCount = 0,
    this.lastCommitDate = '',
    this.branch = '',
    this.prBranch = '',
    this.pushStatus = '',
    this.openPR = '',
    this.ciStatus = '',
    this.ciDate = '',
  });

  RepoInfo copyWith({
    String? name,
    DateTime? folderModified,
    int? uncommittedCount,
    String? lastCommitDate,
    String? branch,
    String? prBranch,
    String? pushStatus,
    String? openPR,
    String? ciStatus,
    String? ciDate,
  }) {
    return RepoInfo(
      name: name ?? this.name,
      folderModified: folderModified ?? this.folderModified,
      uncommittedCount: uncommittedCount ?? this.uncommittedCount,
      lastCommitDate: lastCommitDate ?? this.lastCommitDate,
      branch: branch ?? this.branch,
      prBranch: prBranch ?? this.prBranch,
      pushStatus: pushStatus ?? this.pushStatus,
      openPR: openPR ?? this.openPR,
      ciStatus: ciStatus ?? this.ciStatus,
      ciDate: ciDate ?? this.ciDate,
    );
  }

  @override
  String toString() {
    return 'RepoInfo('
        'name: $name, '
        'folderModified: $folderModified, '
        'uncommittedCount: $uncommittedCount, '
        'lastCommitDate: $lastCommitDate, '
        'branch: $branch, '
        'prBranch: $prBranch, '
        'pushStatus: $pushStatus, '
        'openPR: $openPR, '
        'ciStatus: $ciStatus, '
        'ciDate: $ciDate'
        ')';
  }
}
