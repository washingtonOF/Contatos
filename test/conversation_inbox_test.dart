import 'package:conecta_messenger/features/family/conversation_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Stream<InboxMessage?> preview(String text) => Stream.multi((controller) {
        controller.add(InboxMessage(text, null));
        controller.close();
      }, isBroadcast: true);

  testWidgets('filtra conversas por tipo e busca contatos por celular',
      (tester) async {
    var opened = false;
    final entries = [
      InboxConversation(
        id: 'family/thais',
        title: 'Thaís',
        phone: '+5585999900000',
        isGroup: false,
        onOpen: () => opened = true,
        messages: preview('Já estou a caminho.'),
      ),
      InboxConversation(
        id: 'groups/familia',
        title: 'Família e amigos',
        isGroup: true,
        onOpen: () {},
        messages: preview('Combinado!'),
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConversationInbox(conversations: entries)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Já estou a caminho.'), findsOneWidget);
    expect(find.text('Família e amigos'), findsOneWidget);

    await tester.tap(find.text('Grupos'));
    await tester.pumpAndSettle();
    expect(find.text('Thaís'), findsNothing);
    expect(find.text('Família e amigos'), findsOneWidget);

    await tester.tap(find.text('Todas'));
    await tester.enterText(find.byType(TextField), '9999-0000');
    await tester.pumpAndSettle();
    expect(find.text('Thaís'), findsOneWidget);
    expect(find.text('Família e amigos'), findsNothing);
    await tester.tap(find.text('Thaís'));
    expect(opened, isTrue);
  });
}
