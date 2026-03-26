import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LaunchpadApp());
    expect(find.text('Launchpad'), findsOneWidget);
  });
}
