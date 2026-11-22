import 'package:flutter/material.dart';
import '../../app_name.dart';

class FamilyHomeLayout extends StatelessWidget {
  const FamilyHomeLayout({
    super.key,
    required this.tab,
    required this.body,
    required this.onTabSelected,
    required this.onNewConversation,
    required this.onSignOut,
    this.profilePhoto,
  });

  final int tab;
  final Widget body;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onNewConversation;
  final VoidCallback? onSignOut;
  final ImageProvider? profilePhoto;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title:
              Text([appName, 'Status', 'Família', 'Meu perfil'][tab]),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Opções da conta',
              onSelected: (_) => onSignOut?.call(),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'signout',
                    enabled: onSignOut != null,
                    child: const Text('Sair')),
              ],
            ),
          ],
        ),
        body: body,
        floatingActionButton: tab == 0
            ? FloatingActionButton(
                tooltip: 'Nova conversa',
                onPressed: onNewConversation,
                child: const Icon(Icons.edit_outlined),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: onTabSelected,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Conversas'),
            const NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: 'Status'),
            const NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Família'),
            NavigationDestination(
              icon: profilePhoto == null
                  ? const Icon(Icons.person_outline)
                  : CircleAvatar(radius: 13, foregroundImage: profilePhoto),
              label: 'Perfil',
            ),
          ],
        ),
      );
}
