import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/ritual_theme.dart';

const ritualPrivacyPolicyUrl =
    'https://ritualapp.nishkamk.com/privacy/';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openOnline(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(ritualPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The privacy policy link could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Privacy & health'),
      actions: [
        IconButton(
          tooltip: 'View policy online',
          onPressed: () => _openOnline(context),
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: const [
        _LegalHeader(),
        _PolicySection(
          title: 'Private by design',
          body:
              'Ritual stores journal entries and meal photographs inside the app on this device. It has no account, advertising, analytics, crash-reporting service, or Ritual cloud server. It does not sell personal information.',
        ),
        _PolicySection(
          title: 'Information on your device',
          body:
              'Depending on your choices, Ritual may store meal photos, meal types, feelings, notes, dates, hunger, craving and fullness ratings, coordinates or a place label, preferences, reminder times, and streak progress. Photos stay in app-private storage and do not appear in Android Gallery.',
        ),
        _PolicySection(
          title: 'Location and permissions',
          body:
              'Location is requested only after you tap Use current location and is not accessed in the background. Android or its configured geocoding provider may process coordinates to return a place name. Notifications, camera access, and device authentication are used only for the features you choose.',
        ),
        _PolicySection(
          title: 'Exports',
          body:
              'ZIP, PDF, and CSV exports are created only when you request them and choose where to save them. They are not encrypted. After export, you and the receiving storage provider or recipient control the file.',
        ),
        _PolicySection(
          title: 'Deletion',
          body:
              'Delete individual entries or use Settings → Delete all journal data. Delete-all removes entries, private meal photos, calendar highlights, and streak history. Clearing app storage or uninstalling also removes local data. Previously exported files must be deleted separately.',
        ),
        _PolicySection(
          title: 'Security limits',
          body:
              'Ritual uses Android app-private storage, disables Android backup, and offers an optional app lock. The local database and photos are not individually encrypted, and no device can be guaranteed completely secure.',
        ),
        _PolicySection(
          title: 'Health disclaimer',
          body:
              'Ritual is a personal reflection tool, not a medical device. It does not diagnose, treat, cure, or prevent any disease or medical condition. Its summaries and insights are not medical advice. Consult a qualified healthcare professional for medical advice, diagnosis, or treatment.',
        ),
        _PolicySection(
          title: 'Full policy and contact',
          body:
              'The complete policy is available through View policy online. For privacy questions, use the developer contact on the Google Play listing or the Ritual GitHub repository. Do not put sensitive health or location details in a public GitHub issue.',
        ),
        SizedBox(height: 8),
        Text('Effective August 14, 2026', textAlign: TextAlign.center),
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
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: RitualColors.sage, size: 30),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Your journal remains on your device unless you explicitly export it.',
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
