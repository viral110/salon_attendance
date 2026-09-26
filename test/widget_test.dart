import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_attendance/widgets/status_badge.dart';

void main() {
  testWidgets('SalonAttendanceApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(
            label: '✓ Registered',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          ),
        ),
      ),
    );
    expect(find.byType(StatusBadge), findsOneWidget);
  });
}
