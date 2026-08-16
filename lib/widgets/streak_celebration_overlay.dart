import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/ritual_i18n.dart';
import '../theme/ritual_theme.dart';

class StreakCelebrationOverlay extends StatefulWidget {
  const StreakCelebrationOverlay({super.key, required this.streak});

  final int streak;

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay> {
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2800), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (!mounted || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final celebration = StreakCelebration.forStreak(widget.streak);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: celebration.milestone
                    ? [
                        RitualColors.honey.withValues(alpha: 0.98),
                        RitualColors.terracotta.withValues(alpha: 0.98),
                      ]
                    : [colors.surface, colors.surface],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: celebration.milestone
                        ? Colors.white.withValues(alpha: 0.22)
                        : RitualColors.honey.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    celebration.milestone
                        ? Icons.auto_awesome_rounded
                        : Icons.local_fire_department_rounded,
                    color: celebration.milestone
                        ? Colors.white
                        : RitualColors.honey,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (celebration.milestone)
                        Text(
                          tr('MILESTONE'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                      Text(
                        celebration.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: celebration.milestone
                                  ? Colors.white
                                  : colors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        celebration.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: celebration.milestone
                              ? Colors.white.withValues(alpha: 0.9)
                              : colors.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _close,
                  style: TextButton.styleFrom(
                    foregroundColor: celebration.milestone
                        ? Colors.white
                        : colors.onSurface,
                  ),
                  child: Text(tr('Skip')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StreakCelebration {
  const StreakCelebration({
    required this.title,
    required this.message,
    required this.milestone,
  });

  final String title;
  final String message;
  final bool milestone;

  factory StreakCelebration.forStreak(int streak) {
    return switch (streak) {
      7 => StreakCelebration(
        title: tr('Seven days of showing up'),
        message: tr('A full week of noticing what nourishes you.'),
        milestone: true,
      ),
      30 => StreakCelebration(
        title: tr('Thirty days, gently gathered'),
        message: tr('A month of meals remembered with care.'),
        milestone: true,
      ),
      100 => StreakCelebration(
        title: tr('One hundred mindful days'),
        message: tr('Your small daily ritual has become something lasting.'),
        milestone: true,
      ),
      365 => StreakCelebration(
        title: tr('A year of noticing'),
        message: tr('Three hundred sixty-five days of your life at the table.'),
        milestone: true,
      ),
      1 => StreakCelebration(
        title: tr('Your streak begins'),
        message: tr('The first moment of today is safely in your journal.'),
        milestone: false,
      ),
      _ => StreakCelebration(
        title: tr('{count} day streak', values: {'count': streak}),
        message: tr('Today’s first moment keeps your ritual going.'),
        milestone: false,
      ),
    };
  }
}
