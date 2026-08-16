import '../l10n/ritual_i18n.dart';

enum PersonalIntention {
  rememberMeals,
  noticeHungerFullness,
  understandFeelings,
  mindfulPause,
  noticeJournalPatterns,
}

extension PersonalIntentionCopy on PersonalIntention {
  String get label => switch (this) {
    PersonalIntention.rememberMeals => tr('Remember meals'),
    PersonalIntention.noticeHungerFullness => tr('Notice hunger and fullness'),
    PersonalIntention.understandFeelings => tr(
      'Understand feelings around food',
    ),
    PersonalIntention.mindfulPause => tr('Build a mindful pause'),
    PersonalIntention.noticeJournalPatterns => tr('Notice journal patterns'),
  };

  String get description => switch (this) {
    PersonalIntention.rememberMeals => tr(
      'Keep a dependable record of the meals and snacks that happened.',
    ),
    PersonalIntention.noticeHungerFullness => tr(
      'Pay attention to body cues before and after eating.',
    ),
    PersonalIntention.understandFeelings => tr(
      'Notice emotions and context without judging them.',
    ),
    PersonalIntention.mindfulPause => tr(
      'Create a small moment to slow down and check in.',
    ),
    PersonalIntention.noticeJournalPatterns => tr(
      'See recurring details across your journal over time.',
    ),
  };

  String get todayPrompt => switch (this) {
    PersonalIntention.rememberMeals => tr(
      'Save the next meal or snack you have.',
    ),
    PersonalIntention.noticeHungerFullness => tr(
      'Notice one body cue with your next meal.',
    ),
    PersonalIntention.understandFeelings => tr(
      'Capture how your next eating moment feels.',
    ),
    PersonalIntention.mindfulPause => tr(
      'Take one quiet pause with your next meal.',
    ),
    PersonalIntention.noticeJournalPatterns => tr(
      'Save one detail you may want to notice again later.',
    ),
  };

  String get reflectionHint => switch (this) {
    PersonalIntention.rememberMeals => tr(
      'What would help you remember this meal or snack?',
    ),
    PersonalIntention.noticeHungerFullness => tr(
      'What did you notice in your body before or after eating?',
    ),
    PersonalIntention.understandFeelings => tr(
      'What feelings or circumstances stood out?',
    ),
    PersonalIntention.mindfulPause => tr(
      'What did you notice when you paused?',
    ),
    PersonalIntention.noticeJournalPatterns => tr(
      'Add any detail you may want to compare with later entries.',
    ),
  };

  String get insightNudge => switch (this) {
    PersonalIntention.rememberMeals => tr(
      'This can help make your record clearer.',
    ),
    PersonalIntention.noticeHungerFullness => tr(
      'You might compare this with the body cues you recorded.',
    ),
    PersonalIntention.understandFeelings => tr(
      'You might notice whether the same feelings appear again.',
    ),
    PersonalIntention.mindfulPause => tr(
      'A brief pause may help you notice what is changing.',
    ),
    PersonalIntention.noticeJournalPatterns => tr(
      'This may help you notice a pattern across your journal.',
    ),
  };
}
