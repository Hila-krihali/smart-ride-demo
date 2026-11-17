import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride_management/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartRideApp());
    expect(find.text('Smart Ride'), findsOneWidget);
  });
}
