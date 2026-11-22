import 'package:flutter/material.dart';

enum InboxFilter { all, individual, groups }

class InboxMessage {
  const InboxMessage(this.text, this.time);

  final String text;
  final DateTime? time;
}

class InboxConversation {
  const InboxConversation({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.onOpen,
    required this.messages,
    this.phone = '',
  });

  final String id;
  final String title;
  final String phone;
  final bool isGroup;
  final VoidCallback onOpen;
  final Stream<InboxMessage?> messages;
}

class ConversationInbox extends StatefulWidget {
  const ConversationInbox({
    super.key,
    required this.conversations,
    this.loading = false,
    this.hasError = false,
  });

  final List<InboxConversation> conversations;
  final bool loading;
  final bool hasError;

  @override
  State<ConversationInbox> createState() => _ConversationInboxState();
}

class _ConversationInboxState extends State<ConversationInbox> {
  final _search = TextEditingController();
  InboxFilter _filter = InboxFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final results = widget.conversations.where((entry) {
      final matchesFilter = _filter == InboxFilter.all ||
          entry.isGroup == (_filter == InboxFilter.groups);
      return matchesFilter &&
          (entry.title.toLowerCase().contains(query) ||
              (digits.isNotEmpty &&
                  entry.phone.replaceAll(RegExp(r'\D'), '').contains(digits)));
    }).toList();

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar conversas',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (filter, title) in [
                  (InboxFilter.all, 'Todas'),
                  (InboxFilter.individual, 'Individuais'),
                  (InboxFilter.groups, 'Grupos'),
                ])
                  ChoiceChip(
                    label: Text(title),
                    selected: filter == _filter,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
          ),
        ),
        if (widget.hasError)
          const SliverToBoxAdapter(
            child: ListTile(title: Text('Algumas conversas não carregaram.')),
          ),
        if (widget.loading && results.isEmpty)
          const SliverToBoxAdapter(child: LinearProgressIndicator())
        else if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 36, color: colors.primary),
                    const SizedBox(height: 12),
                    Text(
                      query.isEmpty && _filter == InboxFilter.all
                          ? 'Suas conversas aparecerão aqui'
                          : 'Nenhuma conversa encontrada',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 84),
            sliver: SliverList.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final entry = results[index];
                final palette = [
                  (colors.primaryContainer, colors.onPrimaryContainer),
                  (colors.secondaryContainer, colors.onSecondaryContainer),
                  (colors.tertiaryContainer, colors.onTertiaryContainer),
                ];
                final (background, foreground) =
                    palette[entry.title.length % palette.length];
                return StreamBuilder<InboxMessage?>(
                  key: ValueKey(entry.id),
                  stream: entry.messages,
                  builder: (context, snapshot) {
                    final message = snapshot.data;
                    final time = message?.time?.toLocal();
                    final now = DateTime.now();
                    return ListTile(
                      onTap: entry.onOpen,
                      minTileHeight: 74,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: CircleAvatar(
                        radius: 23,
                        backgroundColor: background,
                        foregroundColor: foreground,
                        child: entry.isGroup
                            ? const Icon(Icons.groups_outlined)
                            : Text(entry.title.trim().isEmpty
                                ? '?'
                                : entry.title
                                    .trim()
                                    .characters
                                    .first
                                    .toUpperCase()),
                      ),
                      title: Text(
                        entry.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        message?.text ??
                            (entry.isGroup ? 'Grupo' : 'Conversa individual'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: time == null
                          ? null
                          : Text(
                              DateUtils.isSameDay(time, now)
                                  ? TimeOfDay.fromDateTime(time).format(context)
                                  : MaterialLocalizations.of(context)
                                      .formatShortDate(time),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
