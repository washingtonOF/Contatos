import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conecta_messenger/main.dart';

void main() {
  testWidgets('IsaMig Mensagens displays welcome screen', (tester) async {
    await tester.pumpWidget(const ConectaApp());
    expect(find.text('IsaMig Mensagens'), findsOneWidget);
    expect(find.text('Conversas que aproximam.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Começar'), findsOneWidget);
  });
}
