import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

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
  String? _selectionError;

  Future<void> _selectTheme(FocusHavenTheme? theme) async {
    if (theme == null || _selectionInProgress) return;
    setState(() {
      _selectionInProgress = true;
      _selectionError = null;
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
        setState(() {
          _selectionError =
              'Appearance could not be updated. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _selectionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(selectedThemeProvider);

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
                          tooltip: 'Back to account settings',
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
                            'Appearance',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the atmosphere that feels best for your focus.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    if (_selectionError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _selectionError!,
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
                        title: Text(theme.label),
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
