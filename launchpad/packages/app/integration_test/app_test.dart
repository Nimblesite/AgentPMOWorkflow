import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:launchpad_app/screens/dashboard.dart';
import 'package:launchpad_app/theme.dart';

/// Test app with auto-refresh disabled for deterministic tests.
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Launchpad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const DashboardScreen(refreshInterval: null),
    );
  }
}

/// Pump the app and wait until job data stabilizes (count stops changing).
Future<void> pumpAppAndWaitForData(WidgetTester tester) async {
  await tester.pumpWidget(const TestApp());
  final end = DateTime.now().add(const Duration(seconds: 60));
  int? lastCount;
  int stableFrames = 0;
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    final count = _tryGetJobCount(tester);
    if (count != null && count > 0) {
      if (count == lastCount) {
        stableFrames++;
        if (stableFrames >= 3) {
          await tester.pump(const Duration(milliseconds: 500));
          return;
        }
      } else {
        stableFrames = 0;
      }
      lastCount = count;
    }
  }
  await tester.pump(const Duration(seconds: 1));
}

int? _tryGetJobCount(WidgetTester tester) {
  final finder = find.textContaining('jobs');
  if (finder.evaluate().isEmpty) return null;
  for (final t in tester.widgetList<Text>(finder)) {
    final match = RegExp(r'(\d+)\s*jobs').firstMatch(t.data ?? '');
    if (match != null) return int.parse(match.group(1)!);
  }
  return null;
}

int getJobCount(WidgetTester tester) {
  final count = _tryGetJobCount(tester);
  if (count != null) return count;
  fail('Could not find "N jobs" text');
}

/// Tap the scope "All" in the sidebar (first "All" text).
Future<void> tapScopeAll(WidgetTester tester) async {
  await tester.tap(find.text('All').first);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Tap the status "All" in the sidebar (second "All" text, after FILTERS header).
Future<void> tapStatusAll(WidgetTester tester) async {
  await tester.tap(find.text('All').at(1));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'E2E: app launch, layout, sidebar, search, sort, detail, XML viewer',
      (tester) async {
    await pumpAppAndWaitForData(tester);

    // ──────── SECTION 1: Initial render ────────

    expect(find.text('Launchpad'), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('Launchpad v0.1.0'), findsOneWidget);
    expect(find.text('SCOPES'), findsOneWidget);
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.text('All'), findsAtLeast(1));
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Loaded'), findsAtLeast(1));
    expect(find.text('Running'), findsAtLeast(1));
    expect(find.text('Errored'), findsAtLeast(1));
    expect(find.byType(TextField), findsAtLeast(1));
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('PID'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Path'), findsOneWidget);

    final allCount = getJobCount(tester);
    expect(allCount, greaterThan(0), reason: 'Must have loaded real launchd jobs');
    expect(find.textContaining('.plist'), findsAtLeast(1));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // ──────── SECTION 2: Scope filtering ────────

    await tester.tap(find.text('User'));
    await tester.pump(const Duration(milliseconds: 500));

    final userCount = getJobCount(tester);
    expect(userCount, lessThanOrEqualTo(allCount));
    if (userCount > 0) {
      expect(find.textContaining('LaunchAgents'), findsAtLeast(1));
    }

    await tester.tap(find.text('System'));
    await tester.pump(const Duration(milliseconds: 500));

    final systemCount = getJobCount(tester);
    expect(systemCount, greaterThan(0), reason: 'macOS always has system jobs');
    expect(find.textContaining('/System/Library'), findsAtLeast(1));

    await tester.tap(find.text('Global'));
    await tester.pump(const Duration(milliseconds: 500));

    final globalCount = getJobCount(tester);

    // Scopes must sum to total
    expect(userCount + globalCount + systemCount, equals(allCount),
        reason:
            'user($userCount) + global($globalCount) + system($systemCount) should == all($allCount)');

    // Reset to all
    await tapScopeAll(tester);
    expect(getJobCount(tester), equals(allCount));

    // ──────── SECTION 3: Status filtering ────────

    await tester.tap(find.text('Running').first);
    await tester.pump(const Duration(milliseconds: 500));

    final runningCount = getJobCount(tester);
    expect(runningCount, greaterThan(0), reason: 'Some jobs should be running');
    expect(runningCount, lessThanOrEqualTo(allCount));

    await tester.tap(find.text('Loaded').first);
    await tester.pump(const Duration(milliseconds: 500));

    final loadedCount = getJobCount(tester);
    expect(loadedCount, greaterThanOrEqualTo(runningCount),
        reason: 'Loaded >= running');

    await tester.tap(find.text('Errored').first);
    await tester.pump(const Duration(milliseconds: 500));

    final erroredCount = getJobCount(tester);
    expect(erroredCount, lessThanOrEqualTo(loadedCount));

    // Reset status filter
    await tapStatusAll(tester);
    expect(getJobCount(tester), equals(allCount));

    // ──────── SECTION 4: Search ────────

    final searchField = find.byType(TextField).first;

    await tester.tap(searchField);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'com.apple');
    await tester.pump(const Duration(milliseconds: 500));

    final appleCount = getJobCount(tester);
    expect(appleCount, greaterThan(0), reason: 'macOS has com.apple jobs');
    expect(appleCount, lessThanOrEqualTo(allCount));
    expect(find.textContaining('com.apple'), findsAtLeast(1));

    await tester.enterText(searchField, 'xyznonexistent99999');
    await tester.pump(const Duration(milliseconds: 500));
    expect(getJobCount(tester), equals(0));
    expect(find.text('No jobs found'), findsOneWidget);

    await tester.enterText(searchField, '');
    await tester.pump(const Duration(milliseconds: 500));
    expect(getJobCount(tester), equals(allCount));

    // ──────── SECTION 5: Combined scope + search ────────

    await tester.tap(find.text('System'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(getJobCount(tester), equals(systemCount));

    await tester.enterText(searchField, 'com.apple');
    await tester.pump(const Duration(milliseconds: 500));

    final sysAppleCount = getJobCount(tester);
    expect(sysAppleCount, greaterThan(0));
    expect(sysAppleCount, lessThanOrEqualTo(systemCount));
    expect(find.textContaining('/System/Library'), findsAtLeast(1));

    await tester.enterText(searchField, '');
    await tapScopeAll(tester);

    // ──────── SECTION 6: Table sorting ────────

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Label'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('PID'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Schedule'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Path'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.text('Path'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    expect(getJobCount(tester), equals(allCount));
    expect(find.textContaining('.plist'), findsAtLeast(1));

    await tester.tap(find.text('Label'));
    await tester.pump(const Duration(milliseconds: 300));

    // ──────── SECTION 7: Job detail panel (system job) ────────

    await tester.tap(find.text('System'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('.plist'), findsAtLeast(1));

    await tester.tap(find.textContaining('.plist').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Schedule'), findsAtLeast(1));
    expect(find.text('Command'), findsAtLeast(1));
    expect(find.text('Paths'), findsAtLeast(1));
    expect(find.text('RunAtLoad'), findsOneWidget);
    expect(find.text('Working Dir'), findsOneWidget);
    expect(find.text('Stdout'), findsOneWidget);
    expect(find.text('Stderr'), findsOneWidget);
    expect(find.text('PID'), findsAtLeast(1));
    expect(find.text('Exit'), findsAtLeast(1));
    expect(find.textContaining('System'), findsAtLeast(1));
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Label'), findsNothing);

    // ──────── SECTION 8: XML viewer toggle ────────

    expect(find.text('Raw Plist'), findsOneWidget);

    final scrollable = find.byType(SingleChildScrollView);
    if (scrollable.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(find.text('Show XML'), 200,
            scrollable: scrollable.first);
        await tester.pump(const Duration(milliseconds: 200));
      } on StateError catch (_) {
        // Already visible
      }
    }

    expect(find.text('Show XML'), findsOneWidget);
    expect(find.text('Hide'), findsNothing);

    await tester.tap(find.text('Show XML'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Show XML'), findsNothing);
    expect(find.textContaining('<?xml'), findsAtLeast(1));
    expect(find.textContaining('<dict>'), findsAtLeast(1));

    await tester.tap(find.text('Hide'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Show XML'), findsOneWidget);
    expect(find.text('Hide'), findsNothing);

    // ──────── SECTION 9: Back to list ────────

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(getJobCount(tester), equals(systemCount));

    await tapScopeAll(tester);
    expect(getJobCount(tester), equals(allCount));
  });

  testWidgets('E2E: user agent detail, actions, search persist, stress test',
      (tester) async {
    await pumpAppAndWaitForData(tester);

    final allCount = getJobCount(tester);
    expect(allCount, greaterThan(0));

    // ──────── User agent detail shows Edit/Delete ────────

    await tester.tap(find.text('User'));
    await tester.pump(const Duration(milliseconds: 500));

    final userCount = getJobCount(tester);
    if (userCount > 0) {
      await tester.tap(find.textContaining('.plist').first);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Schedule'), findsAtLeast(1));
      expect(find.text('Command'), findsAtLeast(1));
      expect(find.text('User Agent'), findsOneWidget);
      expect(find.textContaining('read-only'), findsNothing);

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        try {
          await tester.scrollUntilVisible(find.text('Edit'), 200,
              scrollable: scrollable.first);
          await tester.pump(const Duration(milliseconds: 200));
        } on StateError catch (_) {}
      }

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      final hasLoad = find.text('Load').evaluate().isNotEmpty;
      final hasUnload = find.text('Unload').evaluate().isNotEmpty;
      expect(hasLoad || hasUnload, isTrue, reason: 'Should show Load or Unload');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Label'), findsOneWidget);
    }

    await tapScopeAll(tester);

    // ──────── Search persistence after detail view ────────

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'com.apple');
    await tester.pump(const Duration(milliseconds: 500));

    final searchCount = getJobCount(tester);
    expect(searchCount, greaterThan(0));

    await tester.tap(find.textContaining('.plist').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Schedule'), findsAtLeast(1));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 300));

    expect(getJobCount(tester), equals(searchCount),
        reason: 'Search filter persists through detail view');

    await tester.enterText(searchField, '');
    await tester.pump(const Duration(milliseconds: 500));
    expect(getJobCount(tester), equals(allCount));

    // ──────── Rapid filter switching stress test ────────

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('User'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('System'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Global'));
      await tester.pump(const Duration(milliseconds: 30));
      await tapScopeAll(tester);
    }

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Loaded').first);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Running').first);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Errored').first);
      await tester.pump(const Duration(milliseconds: 30));
      await tapStatusAll(tester);
    }

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Launchpad'), findsOneWidget);
    expect(find.text('SCOPES'), findsOneWidget);
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(getJobCount(tester), equals(allCount));
    expect(find.textContaining('.plist'), findsAtLeast(1));

    // ──────── Refresh button ────────

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump(const Duration(seconds: 3));

    expect(getJobCount(tester), greaterThan(0));
    expect(find.text('Label'), findsOneWidget);
    expect(find.textContaining('.plist'), findsAtLeast(1));
  });

  testWidgets(
      'E2E: full flow — filter, search, sort, detail, XML, back',
      (tester) async {
    await pumpAppAndWaitForData(tester);

    final allCount = getJobCount(tester);
    expect(allCount, greaterThan(0));

    // System scope
    await tester.tap(find.text('System'));
    await tester.pump(const Duration(milliseconds: 500));
    final sysCount = getJobCount(tester);
    expect(sysCount, greaterThan(0));
    expect(sysCount, lessThan(allCount));

    // Search within system
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'com.apple');
    await tester.pump(const Duration(milliseconds: 500));
    final appleCount = getJobCount(tester);
    expect(appleCount, greaterThan(0));
    expect(appleCount, lessThanOrEqualTo(sysCount));

    // Sort
    await tester.tap(find.text('Status'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(getJobCount(tester), equals(appleCount));

    // Open detail
    await tester.tap(find.textContaining('.plist').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Schedule'), findsAtLeast(1));
    expect(find.text('Command'), findsAtLeast(1));
    expect(find.text('Paths'), findsAtLeast(1));
    expect(find.textContaining('System'), findsAtLeast(1));
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.text('PID'), findsAtLeast(1));
    expect(find.text('Exit'), findsAtLeast(1));
    expect(find.text('RunAtLoad'), findsOneWidget);
    expect(find.text('Working Dir'), findsOneWidget);
    expect(find.text('Stdout'), findsOneWidget);
    expect(find.text('Stderr'), findsOneWidget);

    // Toggle XML
    final scrollable = find.byType(SingleChildScrollView);
    if (scrollable.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(find.text('Show XML'), 200,
            scrollable: scrollable.first);
        await tester.pump(const Duration(milliseconds: 200));
      } on StateError catch (_) {}
    }

    await tester.tap(find.text('Show XML'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hide'), findsOneWidget);
    expect(find.textContaining('<?xml'), findsAtLeast(1));

    await tester.tap(find.text('Hide'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Show XML'), findsOneWidget);

    // Back to list
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Label'), findsOneWidget);
    expect(getJobCount(tester), equals(appleCount));

    // Clear search
    await tester.enterText(searchField, '');
    await tester.pump(const Duration(milliseconds: 500));
    expect(getJobCount(tester), equals(sysCount));

    // Back to All
    await tapScopeAll(tester);
    expect(getJobCount(tester), equals(allCount));

    // Final sanity check
    expect(find.text('Launchpad'), findsOneWidget);
    expect(find.text('SCOPES'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
    expect(find.textContaining('.plist'), findsAtLeast(1));
  });
}
