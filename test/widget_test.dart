
import 'package:flutter_test/flutter_test.dart';
import 'package:atmos_iq/main.dart';

void main() {
  testWidgets('AtmosIQ app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AtmosIQApp());

    expect(find.text('AtmosIQ'), findsOneWidget);
    expect(find.text('Weather, made simple.'), findsOneWidget);
  });
}
