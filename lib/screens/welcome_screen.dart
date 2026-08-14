import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../services/meal_reminder_service.dart';
import '../theme/ritual_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  Future<void> _next() async {
    if (_page < 3) {
      await _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _finishing = true);
    await widget.settings.completeOnboarding();
  }

  Future<void> _setReminders(bool value) async {
    final result = await widget.settings.setMealRemindersEnabled(value);
    if (!mounted ||
        result == ReminderToggleResult.enabled ||
        result == ReminderToggleResult.disabled) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == ReminderToggleResult.permissionDenied
              ? 'Notifications were not allowed. You can enable them later in Settings.'
              : 'Reminders are unavailable right now. You can try again later.',
        ),
      ),
    );
  }

  Future<void> _pickTime(MealReminderKind kind, int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Choose reminder time',
    );
    if (picked != null) {
      await widget.settings.setReminderTime(
        kind,
        picked.hour * 60 + picked.minute,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    'RITUAL',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: RitualColors.sage,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing
                        ? null
                        : widget.settings.completeOnboarding,
                    child: const Text('Skip setup'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  const _WelcomePage(
                    icon: Icons.spa_outlined,
                    title: 'Notice, without judgment',
                    body:
                        'Ritual is a private photo journal for meals, feelings, places, and patterns—not calories or scores.',
                    child: _PrivacyPreview(),
                  ),
                  _WelcomePage(
                    icon: Icons.palette_outlined,
                    title: 'Make it feel like yours',
                    body:
                        'Choose an appearance. You can change it at any time.',
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.settings_brightness_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {widget.settings.themeMode},
                      onSelectionChanged: (value) =>
                          widget.settings.setThemeMode(value.single),
                    ),
                  ),
                  _WelcomePage(
                    icon: Icons.tune_rounded,
                    title: 'Choose what you reflect on',
                    body:
                        'The journal stays simple unless you turn on more prompts.',
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: widget.settings.hungerScaleEnabled,
                            onChanged: widget.settings.setHungerScaleEnabled,
                            title: const Text('Hunger before eating'),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: widget.settings.cravingScaleEnabled,
                            onChanged: widget.settings.setCravingScaleEnabled,
                            title: const Text('Craving before eating'),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: widget.settings.fullnessScaleEnabled,
                            onChanged: widget.settings.setFullnessScaleEnabled,
                            title: const Text('Fullness after eating'),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: widget.settings.streaksEnabled,
                            onChanged: widget.settings.setStreaksEnabled,
                            title: const Text('Gentle streaks'),
                            subtitle: const Text(
                              'Optional progress and milestones',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _WelcomePage(
                    icon: Icons.notifications_none_rounded,
                    title: 'Set your rhythm',
                    body:
                        'Reminders are local and automatically skip meals you have already logged.',
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: widget.settings.mealRemindersEnabled,
                            onChanged: _setReminders,
                            title: const Text('Enable reminders'),
                          ),
                          const Divider(height: 1),
                          _WelcomeTimeTile(
                            label: 'Breakfast',
                            minutes: widget
                                .settings
                                .reminderSchedule
                                .breakfastMinutes,
                            onTap: () => _pickTime(
                              MealReminderKind.breakfast,
                              widget.settings.reminderSchedule.breakfastMinutes,
                            ),
                          ),
                          _WelcomeTimeTile(
                            label: 'Lunch',
                            minutes:
                                widget.settings.reminderSchedule.lunchMinutes,
                            onTap: () => _pickTime(
                              MealReminderKind.lunch,
                              widget.settings.reminderSchedule.lunchMinutes,
                            ),
                          ),
                          _WelcomeTimeTile(
                            label: 'Dinner',
                            minutes:
                                widget.settings.reminderSchedule.dinnerMinutes,
                            onTap: () => _pickTime(
                              MealReminderKind.dinner,
                              widget.settings.reminderSchedule.dinnerMinutes,
                            ),
                          ),
                          _WelcomeTimeTile(
                            label: 'Empty-day check-in',
                            minutes: widget
                                .settings
                                .reminderSchedule
                                .emptyDayMinutes,
                            onTap: () => _pickTime(
                              MealReminderKind.emptyDay,
                              widget.settings.reminderSchedule.emptyDayMinutes,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  for (var index = 0; index < 4; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? RitualColors.terracotta
                            : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _finishing ? null : _next,
                    icon: Icon(
                      _page == 3 ? Icons.check_rounded : Icons.arrow_forward,
                    ),
                    label: Text(_page == 3 ? 'Start journaling' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 34, 24, 20),
    children: [
      Icon(icon, size: 48, color: RitualColors.terracotta),
      const SizedBox(height: 24),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        body,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 32),
      child,
    ],
  );
}

class _PrivacyPreview extends StatelessWidget {
  const _PrivacyPreview();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: const [
          _PrivacyLine(
            Icons.phone_android_rounded,
            'Stored only on this device',
          ),
          SizedBox(height: 18),
          _PrivacyLine(
            Icons.no_accounts_outlined,
            'No account or cloud required',
          ),
          SizedBox(height: 18),
          _PrivacyLine(
            Icons.photo_library_outlined,
            'Photos stay out of your gallery',
          ),
        ],
      ),
    ),
  );
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: RitualColors.sage),
      const SizedBox(width: 14),
      Expanded(child: Text(label)),
    ],
  );
}

class _WelcomeTimeTile extends StatelessWidget {
  const _WelcomeTimeTile({
    required this.label,
    required this.minutes,
    required this.onTap,
  });
  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)),
      style: Theme.of(context).textTheme.titleSmall,
    ),
    onTap: onTap,
  );
}
