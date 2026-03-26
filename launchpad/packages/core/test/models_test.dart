import 'package:test/test.dart';
import 'package:launchpad_core/core.dart';

void main() {
  group('JobScope', () {
    test('fromPath identifies user agents', () {
      final home = '/Users/test/Library/LaunchAgents/com.test.plist';
      expect(JobScope.fromPath(home), equals(JobScope.userAgent));
    });

    test('fromPath identifies global agents', () {
      expect(JobScope.fromPath('/Library/LaunchAgents/com.test.plist'),
          equals(JobScope.globalAgent));
    });

    test('fromPath identifies global daemons', () {
      expect(JobScope.fromPath('/Library/LaunchDaemons/com.test.plist'),
          equals(JobScope.globalDaemon));
    });

    test('fromPath identifies system agents', () {
      expect(
          JobScope.fromPath('/System/Library/LaunchAgents/com.apple.test.plist'),
          equals(JobScope.systemAgent));
    });

    test('fromPath identifies system daemons', () {
      expect(
          JobScope.fromPath(
              '/System/Library/LaunchDaemons/com.apple.test.plist'),
          equals(JobScope.systemDaemon));
    });

    test('isSystem returns true for system scopes', () {
      expect(JobScope.systemAgent.isSystem, isTrue);
      expect(JobScope.systemDaemon.isSystem, isTrue);
      expect(JobScope.userAgent.isSystem, isFalse);
      expect(JobScope.globalAgent.isSystem, isFalse);
    });

    test('requiresRoot returns true for global scopes', () {
      expect(JobScope.globalAgent.requiresRoot, isTrue);
      expect(JobScope.globalDaemon.requiresRoot, isTrue);
      expect(JobScope.userAgent.requiresRoot, isFalse);
    });
  });

  group('LaunchdJob', () {
    test('status is running when pid is set', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        isLoaded: true,
        pid: 1234,
      );
      expect(job.status, equals(JobStatus.running));
    });

    test('status is error when loaded with non-zero exit', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        isLoaded: true,
        lastExitStatus: 1,
      );
      expect(job.status, equals(JobStatus.error));
    });

    test('status is loaded when loaded with no errors', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        isLoaded: true,
        lastExitStatus: 0,
      );
      expect(job.status, equals(JobStatus.loaded));
    });

    test('status is notLoaded when not loaded', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
      );
      expect(job.status, equals(JobStatus.notLoaded));
    });

    test('command returns joined programArguments', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        programArguments: ['/usr/bin/python3', 'script.py', '--verbose'],
      );
      expect(job.command, equals('/usr/bin/python3 script.py --verbose'));
    });

    test('command returns program when no arguments', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        program: '/usr/bin/true',
      );
      expect(job.command, equals('/usr/bin/true'));
    });

    test('scheduleDescription formats interval in minutes', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        startInterval: 300,
      );
      expect(job.scheduleDescription, equals('Every 5 min'));
    });

    test('scheduleDescription formats interval in seconds', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        startInterval: 30,
      );
      expect(job.scheduleDescription, equals('Every 30s'));
    });

    test('scheduleDescription formats calendar interval', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        startCalendarInterval: {'Hour': 14, 'Minute': 30},
      );
      expect(job.scheduleDescription, equals('14:30'));
    });

    test('scheduleDescription returns At load for runAtLoad', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        runAtLoad: true,
      );
      expect(job.scheduleDescription, equals('At load'));
    });

    test('copyWith creates modified copy', () {
      final job = LaunchdJob(
        label: 'test',
        path: '/test.plist',
        scope: JobScope.userAgent,
        isLoaded: false,
      );
      final loaded = job.copyWith(isLoaded: true, pid: () => 999);
      expect(loaded.isLoaded, isTrue);
      expect(loaded.pid, equals(999));
      expect(loaded.label, equals('test'));
    });
  });

  group('PlistService', () {
    test('createTemplate generates valid XML with label', () {
      final service = PlistService();
      final template = service.createTemplate('com.example.test');
      expect(template, contains('com.example.test'));
      expect(template, contains('<key>Label</key>'));
      expect(template, contains('<key>ProgramArguments</key>'));
      expect(template, contains('<?xml version'));
    });
  });
}
