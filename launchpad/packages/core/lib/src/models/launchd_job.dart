enum JobScope {
  userAgent,
  globalAgent,
  globalDaemon,
  systemAgent,
  systemDaemon;

  String get displayName => switch (this) {
        userAgent => 'User Agent',
        globalAgent => 'Global Agent',
        globalDaemon => 'Global Daemon',
        systemAgent => 'System Agent',
        systemDaemon => 'System Daemon',
      };

  bool get isSystem =>
      this == JobScope.systemAgent || this == JobScope.systemDaemon;

  bool get requiresRoot =>
      this == JobScope.globalAgent || this == JobScope.globalDaemon;

  static JobScope fromPath(String path) {
    if (path.startsWith('/System/Library/LaunchAgents')) {
      return JobScope.systemAgent;
    } else if (path.startsWith('/System/Library/LaunchDaemons')) {
      return JobScope.systemDaemon;
    } else if (path.startsWith('/Library/LaunchDaemons')) {
      return JobScope.globalDaemon;
    } else if (path.startsWith('/Library/LaunchAgents')) {
      return JobScope.globalAgent;
    } else {
      return JobScope.userAgent;
    }
  }
}

enum JobStatus {
  running,
  loaded,
  notLoaded,
  error;

  String get displayName => switch (this) {
        running => 'Running',
        loaded => 'Loaded',
        notLoaded => 'Not Loaded',
        error => 'Error',
      };
}

class LaunchdJob {
  final String label;
  final String path;
  final JobScope scope;
  final bool isLoaded;
  final int? pid;
  final int? lastExitStatus;
  final String? program;
  final List<String>? programArguments;
  final int? startInterval;
  final Map<String, dynamic>? startCalendarInterval;
  final bool runAtLoad;
  final dynamic keepAlive; // bool or Map
  final String? standardOutPath;
  final String? standardErrorPath;
  final String? workingDirectory;
  final Map<String, String>? environmentVariables;
  final bool disabled;
  final String plistContent;

  LaunchdJob({
    required this.label,
    required this.path,
    required this.scope,
    this.isLoaded = false,
    this.pid,
    this.lastExitStatus,
    this.program,
    this.programArguments,
    this.startInterval,
    this.startCalendarInterval,
    this.runAtLoad = false,
    this.keepAlive,
    this.standardOutPath,
    this.standardErrorPath,
    this.workingDirectory,
    this.environmentVariables,
    this.disabled = false,
    this.plistContent = '',
  });

  JobStatus get status {
    if (pid != null && pid! > 0) return JobStatus.running;
    if (isLoaded && lastExitStatus != null && lastExitStatus != 0) {
      return JobStatus.error;
    }
    if (isLoaded) return JobStatus.loaded;
    return JobStatus.notLoaded;
  }

  String get command {
    if (programArguments != null && programArguments!.isNotEmpty) {
      return programArguments!.join(' ');
    }
    return program ?? '';
  }

  String get scheduleDescription {
    if (startInterval != null) {
      final minutes = startInterval! ~/ 60;
      final seconds = startInterval! % 60;
      if (minutes > 0 && seconds == 0) {
        return 'Every $minutes min';
      } else if (minutes > 0) {
        return 'Every ${minutes}m ${seconds}s';
      }
      return 'Every ${startInterval}s';
    }
    if (startCalendarInterval != null) {
      return _formatCalendarInterval(startCalendarInterval!);
    }
    if (runAtLoad) return 'At load';
    return '-';
  }

  String _formatCalendarInterval(Map<String, dynamic> cal) {
    final parts = <String>[];
    if (cal.containsKey('Hour') && cal.containsKey('Minute')) {
      parts.add(
          '${cal['Hour'].toString().padLeft(2, '0')}:${cal['Minute'].toString().padLeft(2, '0')}');
    }
    if (cal.containsKey('Weekday')) {
      const days = [
        'Sun',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat'
      ];
      final day = cal['Weekday'] as int;
      if (day >= 0 && day < 7) parts.add(days[day]);
    }
    if (cal.containsKey('Day')) {
      parts.add('Day ${cal['Day']}');
    }
    if (cal.containsKey('Month')) {
      parts.add('Month ${cal['Month']}');
    }
    return parts.isEmpty ? 'Calendar' : parts.join(' ');
  }

  LaunchdJob copyWith({
    String? label,
    String? path,
    JobScope? scope,
    bool? isLoaded,
    int? Function()? pid,
    int? Function()? lastExitStatus,
    String? program,
    List<String>? programArguments,
    int? startInterval,
    Map<String, dynamic>? startCalendarInterval,
    bool? runAtLoad,
    dynamic keepAlive,
    String? standardOutPath,
    String? standardErrorPath,
    String? workingDirectory,
    Map<String, String>? environmentVariables,
    bool? disabled,
    String? plistContent,
  }) {
    return LaunchdJob(
      label: label ?? this.label,
      path: path ?? this.path,
      scope: scope ?? this.scope,
      isLoaded: isLoaded ?? this.isLoaded,
      pid: pid != null ? pid() : this.pid,
      lastExitStatus:
          lastExitStatus != null ? lastExitStatus() : this.lastExitStatus,
      program: program ?? this.program,
      programArguments: programArguments ?? this.programArguments,
      startInterval: startInterval ?? this.startInterval,
      startCalendarInterval:
          startCalendarInterval ?? this.startCalendarInterval,
      runAtLoad: runAtLoad ?? this.runAtLoad,
      keepAlive: keepAlive ?? this.keepAlive,
      standardOutPath: standardOutPath ?? this.standardOutPath,
      standardErrorPath: standardErrorPath ?? this.standardErrorPath,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      disabled: disabled ?? this.disabled,
      plistContent: plistContent ?? this.plistContent,
    );
  }
}
