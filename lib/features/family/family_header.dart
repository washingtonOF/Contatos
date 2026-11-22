import 'package:flutter/material.dart';
import '../../app_name.dart';

class FamilyHeader extends StatelessWidget {
  const FamilyHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.showBrand = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const [Color(0xFF1A3251), Color(0xFF1B2639), Color(0xFF3A2749)]
              : const [Color(0xFFEAF3FF), Colors.white, Color(0xFFFBEAF6)],
        ),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBrand)
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/isamig/logo.png',
                      width: 108,
                      height: 46,
                      fit: BoxFit.contain,
                      semanticLabel: 'Grupo Isamig',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appName,
                      style: text.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                  ),
                ],
              )
            else
              CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                child: Icon(icon),
              ),
            const SizedBox(height: 17),
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: colors.tertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: text.headlineSmall?.copyWith(
                fontFamily: 'Manrope',
                fontVariations: const [FontVariation('wght', 800)],
                letterSpacing: -0.6,
                height: 1.15,
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style:
                    text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
