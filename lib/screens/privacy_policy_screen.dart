import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/ritual_i18n.dart';
import '../theme/ritual_theme.dart';

const ritualPrivacyPolicyUrl = 'https://ritualapp.nishkamk.com/privacy/';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openOnline(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(ritualPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('The privacy policy link could not be opened.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Privacy & health')),
      actions: [
        IconButton(
          tooltip: tr('View policy online'),
          onPressed: () => _openOnline(context),
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        const _LegalHeader(),
        _PolicySection(
          title: tr('Private by design'),
          body: tr(
            'Ritual stores journal entries and meal photographs inside the app on this device. It has no account, advertising, analytics, crash-reporting service, or Ritual cloud server. It does not sell personal information.',
          ),
        ),
        _PolicySection(
          title: tr('Information on your device'),
          body: tr(
            'Depending on your choices, Ritual may store meal photos, meal types, feelings, notes, dates, hunger, craving and fullness ratings, a city-and-country label, preferences, reminder times, and streak progress. Photos stay in app-private storage and do not appear in Android Gallery. Older or imported entries may contain coordinates created by earlier versions. Ritual also keeps a bounded technical debug log that excludes journal content, photos, place names, and coordinates. It is shared only if you choose Copy debug log and paste it elsewhere.',
          ),
        ),
        _PolicySection(
          title: tr('Location and permissions'),
          body: tr(
            'Approximate location is requested only after you tap Use approximate location and is not accessed in the background. Android or its configured geocoding provider may process the approximate position to return a city and country. Ritual saves that broad label instead of the newly obtained coordinates. Notifications, camera access, and device authentication are used only for the features you choose.',
          ),
        ),
        _PolicySection(
          title: tr('Exports'),
          body: tr(
            'ZIP, PDF, and CSV exports are created only when you request them and choose where to save them. ZIP backups can use a password with AES-256 encryption; Ritual cannot recover that password. Standard ZIP, PDF, and CSV exports are not encrypted. Share cards contain only selected photos, an optional streak, and Ritual branding; they omit notes, feelings, exact dates, and places. After export or sharing, you and the receiving application, storage provider, or recipient control the file.',
          ),
        ),
        _PolicySection(
          title: tr('Optional support'),
          body: tr(
            'Ritual is free forever. If you choose Visit support page, Android opens ritualapp.nishkamk.com in your browser. Ritual does not send journal data or payment information. Any sponsorship is processed by the external provider under its own terms and privacy policy, and it unlocks no app features or benefits.',
          ),
        ),
        _PolicySection(
          title: tr('Deletion'),
          body: tr(
            'Delete individual entries or use Settings → Delete all journal data. Delete-all removes entries, private meal photos, calendar highlights, and streak history. Clearing app storage or uninstalling also removes local data. Previously exported files must be deleted separately.',
          ),
        ),
        _PolicySection(
          title: tr('Security limits'),
          body: tr(
            'Ritual uses Android app-private storage, disables Android backup, and offers an optional app lock. The local database and photos are not individually encrypted, and no device can be guaranteed completely secure.',
          ),
        ),
        _PolicySection(
          title: tr('Health disclaimer'),
          body: tr(
            'Ritual is a personal reflection tool, not a medical device. It does not diagnose, treat, cure, or prevent any disease or medical condition. Its summaries and insights are not medical advice. Consult a qualified healthcare professional for medical advice, diagnosis, or treatment.',
          ),
        ),
        _PolicySection(
          title: tr('Full policy and contact'),
          body: tr(
            'The complete policy is available through View policy online. For privacy questions, use the developer contact on the Google Play listing or the Ritual GitHub repository. Do not put sensitive health or location details in a public GitHub issue.',
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('Effective August 14, 2026'), textAlign: TextAlign.center),
      ],
    ),
  );
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: RitualColors.sage.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const Icon(Icons.shield_outlined, color: RitualColors.sage, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            tr(
              'Your journal remains on your device unless you explicitly export it.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
}
