import 'package:flutter_test/flutter_test.dart';
import 'package:currencyconverter/main.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PriceScannerApp());

    // We just want to make sure the app builds without crashing for now!
    expect(find.byType(PriceScannerApp), findsOneWidget);
  });
}