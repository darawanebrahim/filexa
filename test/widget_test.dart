import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filexa/app/app.dart';

void main() {
  testWidgets('Filexa app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FilexaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FilexaApp), findsOneWidget);
  });
}