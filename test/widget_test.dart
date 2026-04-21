import 'package:flutter_test/flutter_test.dart';
import 'package:sense_food/main.dart';
import 'package:sense_food/providers/sensor_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Wrap with Provider for testing environment
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SensorProvider()),
        ],
        child: const SenseFoodApp(),
      ),
    );

    // Verify main UI loads keywords
    expect(find.text('Kcal Left'), findsOneWidget);
  });
}
