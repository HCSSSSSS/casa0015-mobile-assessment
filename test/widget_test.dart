import 'package:flutter_test/flutter_test.dart';
import 'package:sense_food/main.dart';
import 'package:sense_food/providers/sensor_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 因为主程序使用了 Provider，测试环境也需要包装 Provider
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SensorProvider()),
        ],
        child: const SenseFoodApp(),
      ),
    );

    // 验证主界面是否加载了关键词
    expect(find.text('Kcal Left'), findsOneWidget);
  });
}
