import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import '../providers/app_providers.dart';
import '../services/theme_service.dart';

class AppearanceSheet extends riverpod.ConsumerWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final selectedTheme = ref.watch(selectedThemeProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: RadioGroup<FocusHavenTheme>(
            groupValue: selectedTheme,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeServiceProvider).setTheme(value);
              }
            },
            child: ListView(
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the atmosphere that feels best for your focus.',
                  style: TextStyle(color: Colors.white70),
                ),
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
    );
  }
}
