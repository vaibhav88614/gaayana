import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaayana/shared/widgets/empty_state.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('EmptyState renders icon and title', (tester) async {
    await tester.pumpWidget(host(
      const EmptyState(icon: Icons.library_music, title: 'No songs'),
    ));
    expect(find.text('No songs'), findsOneWidget);
    expect(find.byIcon(Icons.library_music), findsOneWidget);
  });

  testWidgets('EmptyState renders optional message and action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(
      EmptyState(
        icon: Icons.search_off,
        title: 'Nothing found',
        message: 'Try a different query',
        action: TextButton(
          onPressed: () => tapped++,
          child: const Text('Retry'),
        ),
      ),
    ));
    expect(find.text('Nothing found'), findsOneWidget);
    expect(find.text('Try a different query'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, 1);
  });

  testWidgets('EmptyState omits message and action when not provided',
      (tester) async {
    await tester.pumpWidget(host(
      const EmptyState(icon: Icons.album, title: 'Empty library'),
    ));
    expect(find.byType(TextButton), findsNothing);
    // No message text means only the title's Text appears.
    expect(find.byType(Text), findsOneWidget);
  });
}
