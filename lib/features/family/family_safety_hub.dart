import 'package:flutter/material.dart';

/// Explains supervision capabilities without implying privileged Android access.
/// Location and usage sharing are opt-in features of an accepted family link.
class FamilySafetyHub extends StatelessWidget {
  const FamilySafetyHub({super.key, required this.isResponsible});
  final bool isResponsible;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Proteção familiar')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              isResponsible ? 'Painel do responsável' : 'Minha privacidade',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Supervisão transparente: recursos disponíveis somente com vínculo e permissões válidos.'),
            const SizedBox(height: 20),
            const _Feature(
              icon: Icons.location_on_outlined,
              title: 'Encontrar aparelho',
              description: 'Abra o painel de um familiar vinculado para consultar a última localização compartilhada. Não é rastreamento contínuo.',
            ),
            const _Feature(
              icon: Icons.query_stats_outlined,
              title: 'Tempo de uso',
              description: 'Relatórios dependem de permissão explícita de acesso ao uso no Android e de compartilhamento autorizado.',
            ),
            const _Feature(
              icon: Icons.chat_bubble_outline,
              title: 'Conversas e chamadas',
              description: 'Chat, voz e vídeo funcionam entre participantes. A câmera e o microfone são ativados apenas durante uma chamada aceita.',
            ),
            const _Feature(
              icon: Icons.language_outlined,
              title: 'Sites acessados',
              description: 'Histórico de navegadores externos não está disponível automaticamente. Uma futura navegação protegida precisará de configuração própria e transparência.',
            ),
            const _Feature(
              icon: Icons.tune_outlined,
              title: 'Controles do aparelho',
              description: 'Bloqueio de aplicativos e alterações remotas dependem das APIs e permissões permitidas pelo Android; ainda não estão habilitados.',
            ),
            const _Feature(
              icon: Icons.privacy_tip_outlined,
              title: 'Microfone e câmera',
              description: 'Não existe ativação remota silenciosa. O familiar recebe um convite de chamada e pode aceitar, recusar ou encerrar.',
            ),
            const SizedBox(height: 12),
            const Text('Para localização e relatórios, abra Família e toque no ícone de localização ao lado do contato confirmado.'),
          ],
        ),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(description),
          ),
          isThreeLine: true,
        ),
      );
}
