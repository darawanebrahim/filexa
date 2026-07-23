import 'package:flutter/material.dart';

class FilexaUi {
  FilexaUi._();

  static const primary = Color(0xFF7C4DFF);
  static const deepPurple = Color(0xFF5B35C8);
  static const violet = Color(0xFFA855F7);

  static const heroGradient = LinearGradient(
    colors: [deepPurple, primary, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1722)
        : Colors.white;
  }

  static Color softSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF231E2E)
        : const Color(0xFFF3EDFF);
  }

  static BoxDecoration cardDecoration(BuildContext context, {double radius = 24}) {
    return BoxDecoration(
      color: surface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .35),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4C2A85).withValues(alpha: .08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class FilexaPageHeader extends StatelessWidget {
  const FilexaPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: FilexaUi.primary.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
