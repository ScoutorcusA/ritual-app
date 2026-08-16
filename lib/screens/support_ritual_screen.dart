import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/ritual_i18n.dart';
import '../theme/ritual_theme.dart';

const ritualSupportUrl = 'https://ritualapp.nishkamk.com/support/';

class SupportRitualScreen extends StatelessWidget {
  const SupportRitualScreen({super.key});

  Future<void> _openSupportPage(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(ritualSupportUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('The support page could not be opened.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Support Ritual'))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: RitualColors.terracotta.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                color: RitualColors.terracotta,
                size: 34,
              ),
              const SizedBox(height: 18),
              Text(
                tr('Ritual is free forever.'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(
                  'If Ritual is useful to you, you can optionally support its continued development. Supporting Ritual does not unlock features or change the app in any way.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('The same app for everyone'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _SupportPromise(
                  icon: Icons.check_rounded,
                  text: tr('Every feature remains available without payment.'),
                ),
                _SupportPromise(
                  icon: Icons.check_rounded,
                  text: tr('No supporter badges, special access, or priority.'),
                ),
                _SupportPromise(
                  icon: Icons.check_rounded,
                  text: tr(
                    'No recurring prompts or interruption to journaling.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => _openSupportPage(context),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(tr('Visit support page')),
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            'This opens ritualapp.nishkamk.com in your browser. Ritual sends no journal data or payment information. Any sponsorship is handled by the external provider under its own terms and privacy policy.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _SupportPromise extends StatelessWidget {
  const _SupportPromise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: RitualColors.sage),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
