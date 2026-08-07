import 'package:flutter/material.dart';

class FilexaUi {
  FilexaUi._();

  static const primary = Color(0xFF8B5CF6);
  static const indigo = Color(0xFF4F46E5);
  static const deepPurple = Color(0xFF5B21B6);
  static const violet = Color(0xFFA855F7);
  static const cyan = Color(0xFF38BDF8);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111625)
          : Colors.white;

  static Color softSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181E30)
          : const Color(0xFFF1EBFA);

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF283047)
          : const Color(0xFFE9E3F4);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    double radius = 20,
    bool elevated = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: surface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border(context)),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: .20)
                    : const Color(0xFF4C2A85).withValues(alpha: .08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: FilexaUi.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: FilexaUi.primary.withValues(alpha: .18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .74),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class FilexaSectionTitle extends StatelessWidget {
  const FilexaSectionTitle({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class FilexaEmptyState extends StatelessWidget {
  const FilexaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: FilexaUi.cardDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: FilexaUi.accentGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}


class FilexaPremiumSheet extends StatelessWidget {
  const FilexaPremiumSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
          decoration: BoxDecoration(
            color: FilexaUi.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: FilexaUi.border(context))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .30),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: FilexaUi.accentGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: FilexaUi.border(context)),
              Flexible(child: child),
              if (footer != null) ...[
                Divider(height: 1, color: FilexaUi.border(context)),
                Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 18), child: footer!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FilexaSheetActionCard extends StatelessWidget {
  const FilexaSheetActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? Theme.of(context).colorScheme.error : FilexaUi.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Material(
        color: FilexaUi.softSurface(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: destructive ? accent : null)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
