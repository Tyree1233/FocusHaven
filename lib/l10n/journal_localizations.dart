import 'app_localizations.dart';

/// Maps stable journal mood identifiers to app-owned presentation copy.
///
/// Stored mood identifiers stay unchanged so existing local journals and cloud
/// backups remain compatible. Unknown values pass through as opaque data.
String localizeJournalMood(AppLocalizations l10n, String mood) =>
    switch (mood) {
      'Calm' => l10n.journalMoodCalm,
      'Focused' => l10n.journalMoodFocused,
      'Tired' => l10n.journalMoodTired,
      'Stressed' => l10n.journalMoodStressed,
      'Grateful' => l10n.journalMoodGrateful,
      _ => mood,
    };

String localizeJournalMoodInSentence(AppLocalizations l10n, String mood) =>
    switch (mood) {
      'Calm' => l10n.journalMoodCalmSentence,
      'Focused' => l10n.journalMoodFocusedSentence,
      'Tired' => l10n.journalMoodTiredSentence,
      'Stressed' => l10n.journalMoodStressedSentence,
      'Grateful' => l10n.journalMoodGratefulSentence,
      _ => mood,
    };
