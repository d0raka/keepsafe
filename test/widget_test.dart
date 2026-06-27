import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/ui/screens/onboarding_screen.dart';
import 'package:keepsafe/ui/screens/unlock_screen.dart';

Widget _host(Widget child) =>
    ProviderScope(child: MaterialApp(home: child));

void main() {
  testWidgets('Onboarding screen renders the create-vault form', (tester) async {
    await tester.pumpWidget(_host(const OnboardingScreen()));
    expect(find.text('Create your vault'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create vault'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // password + confirm
  });

  testWidgets('Unlock screen renders the password prompt', (tester) async {
    await tester.pumpWidget(_host(const UnlockScreen()));
    expect(find.widgetWithText(FilledButton, 'Unlock'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Master password'), findsOneWidget);
  });
}
