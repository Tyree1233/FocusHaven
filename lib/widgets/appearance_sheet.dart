import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../l10n/focus_haven_localizations.dart';
import '../providers/app_providers.dart';
import '../services/theme_service.dart';

typedef AppearanceThemeSetter = Future<void> Function(FocusHavenTheme theme);

class AppearanceSheet extends riverpod.ConsumerStatefulWidget {
  const AppearanceSheet({this.setTheme, super.key});

  final AppearanceThemeSetter? setTheme;

  @override
  riverpod.ConsumerState<AppearanceSheet> createState() =>
      _AppearanceSheetState();
}

class _AppearanceSheetState extends riverpod.ConsumerState<AppearanceSheet> {
  bool _selectionInProgress = false;
  bool _selectionFailed = false;

  Future<void> _selectTheme(FocusHavenTheme? theme) async {
    if (theme == null || _selectionInProgress) return;
    setState(() {
      _selectionInProgress = true;
      _selectionFailed = false;
    });
    try {
      final setTheme = widget.setTheme;
      if (setTheme == null) {
        await ref.read(themeServiceProvider).setTheme(theme);
      } else {
        await setTheme(theme);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _selectionFailed = true);
      }
    } finally {
      if (mounted) setState(() => _selectionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(selectedThemeProvider);
    final l10n = context.l10n;

    String themeLabel(FocusHavenTheme theme) => switch (theme) {
      FocusHavenTheme.twilight => l10n.themeTwilight,
      FocusHavenTheme.calmBlue => l10n.themeCalmBlue,
      FocusHavenTheme.minimalist => l10n.themeMinimalist,
      FocusHavenTheme.sunset => l10n.themeSunset,
      FocusHavenTheme.forest => l10n.themeForest,
      FocusHavenTheme.roseQuartz => l10n.themeRoseQuartz,
    };

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: AbsorbPointer(
            key: const Key('appearance-selection-guard'),
            absorbing: _selectionInProgress,
            child: RadioGroup<FocusHavenTheme>(
              groupValue: selectedTheme,
              onChanged: (value) {
                _selectTheme(value);
              },
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l10n.appearanceBackToAccountSettings,
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.appearanceTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appearanceDescription,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_selectionFailed) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.appearanceUpdateError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ...FocusHavenTheme.values.map(
                      (theme) => RadioListTile<FocusHavenTheme>(
                        contentPadding: EdgeInsets.zero,
                        value: theme,
                        title: Text(themeLabel(theme)),
                        secondary: CircleAvatar(backgroundColor: theme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
