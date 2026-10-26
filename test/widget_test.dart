import 'package:flutter_test/flutter_test.dart';
import 'package:weather_forecast_app/main.dart';

void main() {
  testWidgets('Skyora app launches and displays its branding',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SkyoraApp());

    expect(find.text('Skyora'), findsOneWidget);
  });
}
