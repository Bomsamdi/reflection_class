import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflection_class/reflection_class.dart';

void main() {
  setUpAll(() => Reflector.instance.register<Product>(productMirror));
  tearDownAll(Reflector.instance.clear);

  testWidgets('builds the editor from the mirror', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // One control per declared property, the read-only one included.
    expect(find.text('name'), findsOneWidget);
    expect(find.text('price'), findsOneWidget);
    expect(find.text('inStock'), findsOneWidget);
    expect(find.text('label'), findsOneWidget);
    expect(find.text('applyDiscount(10)'), findsOneWidget);
  });

  testWidgets('editing a field writes through the mirror', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextFormField).first, 'Tea');
    await tester.pump();

    expect(find.textContaining('Tea'), findsWidgets);
  });

  testWidgets('calling the method by name changes the value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.textContaining('42.0'), findsWidgets);

    await tester.tap(find.text('applyDiscount(10)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('37.8'), findsWidgets);
  });
}
